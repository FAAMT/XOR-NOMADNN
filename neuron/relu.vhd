library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
library work;
use work.dnn_pkg.all;
entity relu is
	generic (
		DATA_WIDTH : integer := A_WIDTH
	);
	port (
		relu_in  : in signed(DATA_WIDTH - 1 downto 0);
		relu_out : out signed(DATA_WIDTH - 1 downto 0)
	);
end entity relu;
architecture behavioral of relu is
begin
	relu_out <= relu_in when to_integer(signed(relu_in)) >= 0 else (others => '0');
end architecture behavioral;