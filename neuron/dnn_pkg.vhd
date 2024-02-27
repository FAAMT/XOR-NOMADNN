-- dnn_pkg.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
-- Package declaration
package dnn_pkg is
	-- Constant Declarations
	constant NUM_IN     : integer := 2;
	constant NUM_HIDDEN : integer := 4;
	constant NUM_OUT    : integer := 1;
	constant BASE_ADDR  : integer := 0;
	-- Learning Rate
	constant LEARN_RATE : integer := 5;
	-- I/O Bit Widths
	constant DWIDTH_IN  : integer := 1;
	constant DWIDTH_OUT : integer := 1;
	constant W_WIDTH    : integer := 8;
	constant A_WIDTH    : integer := 16;
	constant E_WIDTH    : integer := 8;
	-- Type Declarations
	type hidden_array is array (natural range <>) of std_logic_vector(NUM_IN - 1 downto 0);
	type weights_array is array (natural range <>) of signed(W_WIDTH - 1 downto 0);
	type updated_hidden_weights_array is array (natural range <>) of signed((3 * W_WIDTH) - 1 downto 0);
	type updated_input_weights_array is array (natural range <>) of signed((5 * W_WIDTH) - 1 downto 0);
	type input_array is array (natural range <>) of signed(W_WIDTH - 1 downto 0);
	type ol_output_array is array (natural range <>) of signed(24 - 1 downto 0);
	type output_array is array (natural range <>) of signed(A_WIDTH - 1 downto 0);
	type network_in_array is array (natural range <>) of std_logic_vector(DWIDTH_OUT - 1 downto 0);
	type network_out_array is array (natural range <>) of std_logic_vector(DWIDTH_OUT - 1 downto 0);
	type custom_array is array (natural range <>) of signed(24 - 1 downto 0);
	type error_array is array (natural range <>) of signed(E_WIDTH - 1 downto 0);
	type delta_1_array is array (natural range <>) of signed((3 * E_WIDTH) - 1 downto 0);
	type delta_2_array is array (natural range <>) of signed(E_WIDTH - 1 downto 0);
	-- Declare the log2 function
	function log2(n : natural) return natural;
	function ceil(n : integer) return integer;
end package dnn_pkg;
-- Package body
package body dnn_pkg is
	function ceil(n : integer) return integer is
	variable result : integer := 0;
	variable m      : integer := n - 1; -- Adjust because we want ceil(log2(n))
	begin
		while (m > 0) loop
		m      := m / 2;
		result := result + 1;
	end loop; return result;
	end function ceil;
	-- Implementation of the log2 function
	function log2(n : natural) return natural is
	variable result : natural := 0;
	begin
		while (2 ** result < n) loop
		result := result + 1;
	end loop; return result;
end function log2;
end package body dnn_pkg;