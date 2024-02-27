library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.dnn_pkg.all;
entity tb_neuron is
end tb_neuron;
architecture behavior of tb_neuron is
	--inputs
	signal clk         : std_logic := '0';
	signal rst         : std_logic := '0';
	signal start       : std_logic := '0';
	signal input_data  : input_array(NUM_IN - 1 downto 0) := (others => (others => '0'));
	signal weight_data : signed(W_WIDTH - 1 downto 0);
	signal load_weight : std_logic;
	signal load_index  : integer range 0 to NUM_IN;
	--outputs
	signal done        : std_logic;
	signal output_data : std_logic_vector(DWIDTH_OUT - 1 downto 0);
	-- Clock period definitions
	constant clk_period : time := 10 ns;
begin
	-- instantiate the Unit Under Test (UUT)
	uut : entity work.neuron
			generic map(
			NUM_IN => NUM_IN
			)
			port map(
				clk         => clk,
				rst         => rst,
				start       => start,
				input_data  => input_data,
				output_data => output_data,
				weight_data => weight_data,
				done        => done,
				load_weight => load_weight,
				load_index  => load_index
			);
				-- Clock process definitions
				clk_process : process
				begin
					clk <= '0';
					wait for clk_period/2;
					clk <= '1';
					wait for clk_period/2;
				end process;
				-- Test process
				stim_proc : process
				begin
					-- reset
					rst <= '1';
					wait for 20 ns;
					rst <= '0';
					wait for 10 ns;

					-- Load arbitrary weights for 3 inputs and one bias weight
					for i in 0 to NUM_IN loop
						load_weight <= '1';
						load_index  <= i; -- Adjust index for 3 inputs
						weight_data <= to_signed((i + 1) * 2, weight_data'length); -- Example weight
						wait for clk_period * 2;
						load_weight <= '0'; -- Ensure load_weight is disabled after setting
					end loop;
					-- initialize inputs
					start <= '0';
					for i in 0 to NUM_IN - 1 loop
						input_data(i) <= std_logic_vector(to_signed(i, input_data(i)'length)); -- Adjusted for correct bit width
					end loop;
					wait for clk_period * 2;
					-- Stimulate the start signal to begin operation
					start <= '1';
					wait for clk_period;
					start <= '0';
					-- wait for FSM to finish processing
					wait for 200 ns;
					wait;
				end process;
end behavior;