library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity rgb_encoder is
	port( 
		CLK14M 	: in std_logic;
		CREF		: in std_logic;
		nSEROUT	: in std_logic;
		nSYNC		: in std_logic;
		TEXT		: in std_logic;
		GR			: in std_logic;
		
		RED		: out std_logic_vector(1 downto 0);
		GREEN		: out std_logic_vector(1 downto 0);
		BLUE		: out std_logic_vector(1 downto 0);
		nSYNCOUT	: out std_logic
	);
end rgb_encoder;

architecture rtl of rgb_encoder is

signal R : std_logic_vector(1 downto 0) := "00";
signal G : std_logic_vector(1 downto 0) := "00";
signal B : std_logic_vector(1 downto 0) := "00";

signal COLCLK		: std_logic_vector(3 downto 0) := "1111";
signal COLPAT		: std_logic_vector(3 downto 0) := "1111";

begin

RED <= R;
GREEN <= G;
BLUE <= B;
nSYNCOUT <= nSYNC;

process(CLK14M, nSEROUT, CREF, GR)
variable COLPAT2	: std_logic_vector(3 downto 0);
begin
	if falling_edge(CLK14M) then
		COLCLK <= COLCLK(2 downto 0) & CREF;
		COLPAT <= COLPAT(2 downto 0) & nSEROUT;
		if GR = '1' then
			if COLCLK = "0011" or COLCLK = "1100" then
			if COLCLK = "0011" then
				COLPAT2 := COLPAT;
			else
				COLPAT2 := COLPAT(1 downto 0) & COLPAT(3 downto 2);
			end if;
			
				case COLPAT2 is
				when "1011" => -- 1 - 0x90 17 40
					R <= "10";
					G <= "00";
					B <= "01";
				when "1101" => -- 2 - 0x40 2c a5
					R <= "01";
					G <= "00";
					B <= "10";
				when "1001" => -- 3 - 0xd0 43 e5
					R <= "11";
					G <= "01";
					B <= "11";
				when "1110" => -- 4 - 0x00 69 40
					R <= "00";
					G <= "01";
					B <= "01";
				when "1010" => -- 5 - 0x80 80 80
					R <= "10";
					G <= "10";
					B <= "10";
				when "1100" => -- 6 - 0x2f 95 e5 
					R <= "00";
					G <= "10";
					B <= "11";
				when "1000" => -- 7 - 0xbf ab ff
					R <= "11";
					G <= "10";
					B <= "11";
				when "0111" => -- 8 - 0x40 54 00
					R <= "01";
					G <= "01";
					B <= "00";
				when "0011" => -- 9 - 0xd0 6a 1a 
					R <= "11";
					G <= "01";
					B <= "00";
				when "0101" => -- 10 - 0x80 80 80
					R <= "01";
					G <= "01";
					B <= "01";
				when "0001" => -- 11 - 0xff 96 bf
					R <= "11";
					G <= "10";
					B <= "11";
				when "0110" => -- 12 - 0x2f bc 1a 
					R <= "00";
					G <= "11";
					B <= "00";
				when "0010" => -- 13 - 0xbf d3 5a
					R <= "11";
					G <= "11";
					B <= "01";
				when "0100" => -- 14 - 0x6f e8 bf
					R <= "01";
					G <= "11";
					B <= "11";
				when "0000" => -- 15 - 0xff ff ff 
					R <= "11";
					G <= "11";
					B <= "11";
				when others => -- 0 - 0x00 00 00
					R <= "00";
					G <= "00";
					B <= "00";
				end case;
			end if;
		else
			if COLPAT(3) = '1' then
				R <= "00";
				G <= "00";
				B <= "00";
			else
				R <= "11";
				G <= "11";
				B <= "11";
			end if;
		end if;
	end if;
end process;

end rtl;

