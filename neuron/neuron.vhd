library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
library work;
use work.dnn_pkg.all;
entity neuron is
	generic (
		NUM_IN     : integer := NUM_IN;
		NUM_OUT    : integer := NUM_OUT;
		NUM_HIDDEN : integer := NUM_HIDDEN;
		BASE_ADDR  : integer := BASE_ADDR;
		WIDTH_IN   : integer := W_WIDTH;
		WIDTH_OUT  : integer := A_WIDTH
	);
	port (
		-- Clk & Rst
		clk : in std_logic;
		rst : in std_logic;
		-- Start-Done Custom Interface
		start : in std_logic;
		done  : out std_logic;
		-- Data Signals
		input_data  : in signed(NUM_IN * WIDTH_IN - 1 downto 0);
		output_data : out signed(WIDTH_OUT - 1 downto 0);
		-- Weight Signals
		weight_data : in signed(7 downto 0);
		load_weight : in std_logic;
		load_bias   : in std_logic;
		load_index  : in integer range 0 to NUM_IN + NUM_HIDDEN + NUM_OUT
	);
end entity neuron;
architecture behavioral of neuron is
	-- Type Declarations
	type state_type is (idle, reg_inputs, mult, sum);
	type input_array is array (NUM_IN - 1 downto 0) of signed(WIDTH_IN - 1 downto 0);
	-- Signal Declarations
	signal index      : integer := 0;
	signal state      : state_type := idle;
	signal done_i     : std_logic := '0';
	signal data_reg   : input_array;
	signal accumulate : signed(WIDTH_OUT - 1 downto 0);
	signal multiply   : signed(WIDTH_OUT - 1 downto 0);
	signal weights    : weights_array(NUM_IN downto 0);
begin
	-- data_conv <= "0000000" & data_reg(index);
	-- Loading Weights
	weights_process : process (clk, rst)
	begin
		if rst = '1' then
			weights <= (others => (others => '0'));
		elsif rising_edge(clk) then
			if load_bias = '1' then
				weights(NUM_IN) <= weight_data; -- bias register
			elsif load_weight = '1' then
				weights(load_index) <= weight_data; -- specified index
			end if;
		end if;
	end process weights_process;
	-- FSM Process
	fsm_process : process (clk, rst)
	begin
		if rst = '1' then
			state    <= idle;
			data_reg <= (others => (others => '0'));
			done     <= '0';
		elsif rising_edge(clk) then
			case state is
				when idle =>
					done <= '0';
					if start = '1' then
						state <= reg_inputs;
					end if;
				when reg_inputs =>
					for i in 0 to NUM_IN - 1 loop
						data_reg(i) <= input_data((i + 1) * WIDTH_IN - 1 downto (i * WIDTH_IN)); -- assign each vector to its corresponding input_data vector
					end loop;
					accumulate <= (others => '0'); -- reset accumulator
					multiply   <= (others => '0'); -- reset accumulator
					index      <= NUM_IN - 1; -- set index
					state      <= mult;
				when mult =>
					if index = NUM_IN - 1 then
						accumulate <= signed(weights(NUM_IN)(7) & resize(weights(NUM_IN)(6 downto 0), accumulate'LENGTH - 1)); -- initialize accumulate with bias
					end if;
					if index >= 0 and index < NUM_IN then
						multiply <= data_reg(index) * weights(index);
					end if;
					state <= sum;
				when sum =>
					accumulate <= accumulate + multiply;
					if index = 0 then
						done  <= '1'; -- Neuron Synapse Fired
						state <= idle;
					else
						state <= mult;
						index <= index - 1;
					end if;
			end case;
		end if;
	end process fsm_process;
	-- ReLU component instantiation
	relu_inst : entity work.relu
			generic map(
			DATA_WIDTH => WIDTH_OUT
			)
			port map(
				relu_in  => accumulate,
				relu_out => output_data
			);
end behavioral;