library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_MISC.all;
use IEEE.NUMERIC_STD.all;
library work;
use work.dnn_pkg.all;
entity gradient_descent is
	generic (
		NUM_IN     : integer := NUM_IN;
		NUM_HIDDEN : integer := NUM_HIDDEN;
		NUM_OUT    : integer := NUM_OUT;
		LEARN_RATE : integer := LEARN_RATE
	);
	port (
		-- Clk & Rst
		clk  : in std_logic;
		rst  : in std_logic;
		load : in std_logic;
		-- Input/Output Vectors
		input_data           : in input_array(NUM_IN - 1 downto 0);
		hidden_layer_outputs : in output_array(NUM_HIDDEN - 1 downto 0);
		output_layer_outputs : in ol_output_array(NUM_OUT - 1 downto 0);
		-- Result/Target Data
		result : in std_logic;
		target : in std_logic;
		-- Error Signals
		delta_1 : out delta_1_array(NUM_HIDDEN - 1 downto 0); -- Adjusted Bit Width
		delta_2 : out delta_2_array(NUM_OUT - 1 downto 0); -- Adjusted Bit Width
		-- Current Weights
		input_hidden_weights  : in weights_array(NUM_IN * NUM_HIDDEN downto 0); -- Current Input-Hidden Weights
		hidden_output_weights : in weights_array(NUM_HIDDEN * NUM_OUT downto 0); -- Current Hidden-Output Weights
		-- Updated Weights
		updated_input_weights  : out updated_input_weights_array(NUM_IN * NUM_HIDDEN downto 0); -- Adjusted Data Type
		updated_hidden_weights : out updated_hidden_weights_array(NUM_HIDDEN * NUM_OUT downto 0) -- Adjusted Data Type
	);
end entity gradient_descent;
architecture behavior of gradient_descent is
	signal f_prime_z1  : error_array(NUM_HIDDEN - 1 downto 0); -- Adjusted Bit Width
	signal temp_weight : updated_input_weights_array(NUM_IN * NUM_HIDDEN downto 0); -- Adjusted Data Type
begin
	-- Hidden Layer Error Calculation
	hidden_layer_error : process (clk)
	begin
		if rst = '1' then
			delta_1    <= (others => (others => '0'));
			f_prime_z1 <= (others => (others => '0'));
		elsif rising_edge(clk) then
			for j in 0 to NUM_OUT - 1 loop
				for i in 0 to NUM_HIDDEN - 1 loop
					-- Interpret hidden_layer_outputs as signed and compare to 0
					-- This assumes hidden_layer_outputs are stored in a format that allows for numeric interpretation
					if load = '1' then
						if to_integer(signed(hidden_layer_outputs(i))) > 0 then
							f_prime_z1(i) <= resize(to_signed(1, E_WIDTH), f_prime_z1(i)'length); -- Derivative is 1 for x > 0
						else
							f_prime_z1(i) <= resize(to_signed(0, E_WIDTH), f_prime_z1(i)'length); -- Derivative is 0 for x <= 0
						end if;
						delta_1(i) <= delta_2(j) * hidden_output_weights(i) * f_prime_z1(i); -- Hidden Error Per Neuron
					else
						delta_1    <= delta_1;
						f_prime_z1 <= f_prime_z1;
					end if;
				end loop;
			end loop;
		end if;
	end process hidden_layer_error;
	-- Output Layer Error Calculation
	calc_error_proc : process (clk)
	begin
		if rst = '1' then
			delta_2 <= (others => (others => '0'));
		elsif rising_edge(clk) then
			for i in 0 to NUM_OUT - 1 loop
				if load = '1' then
					if result = target then
						delta_2(i) <= resize(to_signed(0, E_WIDTH), delta_2(i)'length); -- Adjusted for E_WIDTH
					else
						delta_2(i) <= resize(to_signed(1, E_WIDTH), delta_2(i)'length); -- Adjusted for E_WIDTH
					end if;
				else
					delta_2 <= delta_2;
				end if;
			end loop;
		end if;
	end process calc_error_proc;
	-- Weight Update Mechanism
	weight_update_proc : process (clk)
	begin
		if rst = '1' then
			updated_input_weights  <= (others => (others => '0'));
			updated_hidden_weights <= (others => (others => '0'));
		elsif rising_edge(clk) then
			if load = '1' then
				-- Update Hidden-Output Weights
				for i in 0 to NUM_HIDDEN - 1 loop
					for j in 0 to NUM_OUT - 1 loop
						-- Adjusted weight update to match bit widths and data types
						updated_hidden_weights(i * NUM_OUT + j) <= hidden_output_weights(i * NUM_OUT + j) - resize(to_signed(LEARN_RATE, W_WIDTH), hidden_output_weights(i * NUM_OUT + j)'length) *
							delta_2(j) * resize(to_signed(to_integer(unsigned(hidden_layer_outputs(i))), W_WIDTH), hidden_output_weights(i * NUM_OUT + j)'length);
					end loop;
				end loop;
				updated_hidden_weights(NUM_HIDDEN) <= resize(hidden_output_weights(NUM_HIDDEN), updated_hidden_weights(NUM_HIDDEN)'length) - resize(to_signed(LEARN_RATE, W_WIDTH), hidden_output_weights(NUM_HIDDEN)'length) * delta_2(0);
				-- Update Input-Hidden Weights
				for j in 0 to NUM_HIDDEN - 1 loop
					for i in 0 to NUM_IN - 1 loop
						-- Adjusted weight update to match bit widths and data types
						temp_weight(j * NUM_IN + i) <= input_hidden_weights(j * NUM_IN + i) - resize(to_signed(LEARN_RATE, W_WIDTH), input_hidden_weights(j * NUM_IN + i)'length) *
							delta_1(j) * resize(to_signed(to_integer(unsigned(input_data(i))), W_WIDTH), input_hidden_weights(j * NUM_IN + i)'length);
							if temp_weight(j * NUM_IN + i) > to_signed(127, W_WIDTH) then
								updated_input_weights(j * NUM_IN + i) <= to_signed(127, 5 * W_WIDTH); -- Cap at max positive value
							elsif temp_weight(j * NUM_IN + i) < to_signed( - 128, W_WIDTH) then
								updated_input_weights(j * NUM_IN + i) <= to_signed( - 128, 5 * W_WIDTH); -- Cap at max negative value
							else
								updated_input_weights(j * NUM_IN + i) <= temp_weight(j * NUM_IN + i); -- Within range, assign directly
							end if;
					end loop;
				end loop;
			else
				updated_hidden_weights <= updated_hidden_weights;
				updated_input_weights  <= updated_input_weights;
			end if;
		end if;
	end process weight_update_proc;
end behavior;