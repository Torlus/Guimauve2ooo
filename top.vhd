library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity top is
	port( 
		CLK14M 	: in std_logic;
		CREF		: in std_logic;
		nPRAS		: in std_logic;
		nLDPS		: in std_logic;
		VIDD7		: in std_logic;
		nSEROUT	: in std_logic;
		nWNDW		: in std_logic;
		nSYNC		: in std_logic;
		TEXT		: in std_logic;
		SEGB		: in std_logic;
		GR			: in std_logic;
		
		RED		: out std_logic_vector(1 downto 0);
		GREEN		: out std_logic_vector(1 downto 0);
		BLUE		: out std_logic_vector(1 downto 0);
		nSYNCOUT	: out std_logic;
		
		VGA_HS	: out std_logic;
		VGA_VS	: out std_logic;
		VGA_R		: out std_logic;
		VGA_G		: out std_logic;
		VGA_B		: out std_logic
	);
end top;

architecture rtl of top is

begin

RGB : entity work.rgb_encoder
	port map(
		CLK14M 	=> CLK14M,
		CREF		=> CREF,
		nSEROUT	=> nSEROUT,
		nSYNC		=> nSYNC,
		TEXT		=> TEXT,
		GR			=> GR,
		RED		=> RED,
		GREEN		=> GREEN,
		BLUE		=> BLUE,
		nSYNCOUT	=> nSYNCOUT
	);

VGA : entity work.vga_controller
	port map(
		CLK_14M 		=> CLK14M,
		nVIDEO		=> nSEROUT,
		COLOR_LINE 	=> GR,
		CBL			=> nWNDW,
		nLDPS			=> nLDPS,
	 
		VGA_HS		=> VGA_HS,
		VGA_VS		=> VGA_VS,
		VGA_R			=> VGA_R,
		VGA_G			=> VGA_G,
		VGA_B			=> VGA_B	
	);

end rtl;

