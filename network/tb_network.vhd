library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.STD_LOGIC_TEXTIO.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
library std;
use std.textio.all;
use std.env.all;

library work;
use work.dnn_pkg.all;
entity tb_network is
	-- Empty entity for testbench
end entity tb_network;
architecture behavior of tb_network is
	constant NUM_IN        : integer := 2;
	constant NUM_HIDDEN    : integer := 4;
	constant NUM_OUT       : integer := 1;
	signal clk             : std_logic := '0';
	signal rst             : std_logic;
	signal start           : std_logic;
	signal done            : std_logic;
	signal input_data      : network_in_array(NUM_IN - 1 downto 0);
	signal output_data     : ol_output_array(NUM_OUT - 1 downto 0);
	signal expected_output : std_logic;
	signal target          : std_logic;
	signal result          : std_logic;
	signal weight_data     : signed(W_WIDTH - 1 downto 0);
	signal load_weight     : std_logic;
	signal load_bias       : std_logic;
	signal load_index      : integer range 0 to NUM_HIDDEN * NUM_IN + NUM_HIDDEN * NUM_OUT;
	-- Clock period definitions
	constant clk_period     : time := 10 ns;
	signal cycle_counter    : natural := 0; -- Cycle counter
	signal processing_start : boolean := false; -- Flag to indicate start of processing
	-- Declare file-related objects
	file weight_file : text;
	-- Define test vectors
	type test_vector is record
	input_values          : network_in_array(NUM_IN - 1 downto 0);
	expected_output_value : std_logic;
end record;
type test_vector_array is array (integer range <>) of test_vector;
constant TEST_ITER    : integer := 5;
constant TEST_VECTORS : test_vector_array(0 to 3) := (
	(input_values => (0 => b"0", 1 => b"0"), expected_output_value => '0'),
	(input_values => (0 => b"0", 1 => b"1"), expected_output_value => '1'),
	(input_values => (0 => b"1", 1 => b"0"), expected_output_value => '1'),
	(input_values => (0 => b"1", 1 => b"1"), expected_output_value => '0')
);
begin
	-- Instantiate the Unit Under Test (UUT)
	uut : entity work.network
			generic map(
			NUM_IN     => NUM_IN,
			NUM_HIDDEN => NUM_HIDDEN,
			NUM_OUT    => NUM_OUT,
			BASE_ADDR  => BASE_ADDR
			)
			port map(
				clk         => clk,
				rst         => rst,

				start       => start,
				done        => done,

				input_data  => input_data,
				output_data => output_data,

				target      => target,
				result      => result,

				weight_data => weight_data,
				load_weight => load_weight,
				load_bias   => load_bias,
				load_index  => load_index
			);
				-- Clock process definitions
				clk_process : process
				begin
					clk <= '0';
					wait for clk_period / 2;
					clk <= '1';
					wait for clk_period / 2;
				end process;
				-- Test process
				stim_proc             : process
					variable weight_line  : line;
					variable weight_value : real; -- Change to real type
					variable retry_count  : integer;
					constant max_retries  : integer := 15;
				begin
					-- Initialize Inputs
					start       <= '0';
					load_index  <= 0;
					load_bias   <= '0';
					load_weight <= '0';
					weight_data <= (others => '0');
					rst         <= '1';
					wait for 2 * clk_period;
					rst <= '0';
					wait for 2 * clk_period;
					-- Initialize network weights
					file_open(weight_file, "scripts/weights/input_hidden_weights.txt", read_mode);
					load_weight <= '1';
					-- Input-Hidden Connection Weights
					for i in 0 to NUM_HIDDEN - 1 loop
						readline(weight_file, weight_line);
						read(weight_line, weight_value);
						weight_data <= signed(to_signed(integer(weight_value), weight_data'length));
						wait for 1 * clk_period;
						load_index <= load_index + 1;
						read(weight_line, weight_value);
						weight_data <= signed(to_signed(integer(weight_value), weight_data'length));
						wait for 1 * clk_period;
						read(weight_line, weight_value);
						load_bias   <= '1';
						weight_data <= signed(to_signed(integer(weight_value), weight_data'length));
						wait for 1 * clk_period;
						load_bias  <= '0';
						load_index <= load_index + 1;
					end loop;
					file_close(weight_file);
					file_open(weight_file, "scripts/weights/hidden_output_weights.txt", read_mode);
					-- Hidden-Output Connection Weights
					for i in 0 to NUM_OUT - 1 loop
						readline(weight_file, weight_line);
						for j in 0 to NUM_HIDDEN - 1 loop
							read(weight_line, weight_value);
							weight_data <= signed(to_signed(integer(weight_value), weight_data'length));
							wait for 1 * clk_period;
							if j = NUM_HIDDEN - 1 then
								read(weight_line, weight_value);
								load_bias   <= '1';
								weight_data <= signed(to_signed(integer(weight_value), weight_data'length));
								wait for 1 * clk_period;
								load_bias <= '0';
							end if;
							load_index <= load_index + 1;
						end loop;
					end loop;
					load_weight <= '0';
					file_close(weight_file);
					for j in 0 to TEST_ITER loop
						for i in TEST_VECTORS'range loop
							retry_count       := 0;
							test_vector_retry :
							while retry_count <= max_retries loop
								input_data        <= TEST_VECTORS(i).input_values;
								target            <= TEST_VECTORS(i).expected_output_value;
								start             <= '1'; -- Start the network
								wait for 1 * clk_period;
								start <= '0'; -- Stop the network
								-- Wait for the done signal to pulse
								wait until done = '1';
								wait for 2 * clk_period;
								-- Check the output_data with an expected value
								if result /= target then
									-- report "Output data does not match expected value on iter " & integer'image(i) & ", retry " & integer'image(retry_count) severity note;
									retry_count := retry_count + 1;
								else
									report "Output data matched expected value OF test vector " & integer'image(i) & " ON retry " & integer'image(retry_count) severity note;
									exit test_vector_retry; -- Exit retry loop on success
								end if;
						end loop;
						if retry_count > max_retries then
							report "Maximum retries exceeded FOR test vector " & integer'image(i) severity error;
						end if;
						wait for 5 * clk_period;
					end loop;
				end loop;
				-- Finish the testbench
				wait for 5 * clk_period;
				report "Testbench Successfully Completed";
				finish;
				wait;
				end process;
				-- Increment cycle counter with each clock cycle
				process (clk)
					begin
						if rising_edge(clk) then
							if processing_start then
								cycle_counter <= cycle_counter + 1;
							elsif start = '1' then
								cycle_counter <= 0;
							end if;
						end if;
					end process;
					-- Reset cycle counter and set processing start flag at the beginning of processing a test vector
					-- (You need to determine the appropriate condition for starting processing based on your design)
					process (start, done)
						begin
							if start'EVENT and start = '1' then
								processing_start <= true; -- Indicate start of processing
							elsif done'EVENT and done = '1' then
								report "Cycles FOR test vector: " & integer'image(cycle_counter);
								processing_start <= false; -- Reset processing start flag
								-- Optionally calculate cycles per MAC here if MAC count is known
							end if;
						end process;
end behavior;