-------------------------------------------------------------------------------
--
-- A VGA line-doubler for an Apple ][
--
-- Stephen A. Edwards, sedwards.cs.columbia.edu
--
-- The Apple ][ uses a 14.31818 MHz master clock.  It outputs a new
-- horizontal line every 65 * 14 + 2 = 912 14M cycles.  The extra two
-- are from the "extended cycle" used to keep the 3.579545 MHz
-- colorburst signal in sync.  Of these, 40 * 14 = 560 are active video.
--
-- In graphics mode, the Apple effectively generates 140 four-bit pixels
-- output serially (i.e., with 3.579545 MHz pixel clock).  In text mode,
-- it generates 280 one-bit pixels (i.e., with a 7.15909 MHz pixel clock).
--
-- We capture 140 four-bit nibbles for each line and interpret them in
-- one of the two modes.  In graphics mode, each is displayed as a
-- single pixel of one of 16 colors.  In text mode, each is displayed
-- as two black or white pixels.
-- 
-- The VGA display is nominally 640 X 480, but we use a 14.31818 MHz
-- dot clock.  To stay in sync with the Apple, we generate a new line
-- every 912 / 2 = 456 14M cycles= 31.8 us, a 31.4 kHz horizontal
-- refresh rate.  Of these, 280 will be active video.
--
-- One set of suggested VGA timings:
--
--          ______________________          ________
-- ________|        VIDEO         |________| VIDEO
--     |-C-|----------D-----------|-E-|
-- __   ______________________________   ___________
--   |_|                              |_|
--   |B|
--   |---------------A----------------|
--
-- A = 31.77 us	 Scanline time
-- B =  3.77 us  Horizontal sync time
-- C =  1.89 us  Back porch
-- D = 25.17 us  Active video
-- E =  0.94 us  Front porch
--
-- We use A = 456 / 14.31818 MHz = 31.84 us
--        B =  54 / 14.31818 MHz =  3.77 us
--        C = 106 / 14.31818 MHz =  7.40 us
--        D = 280 / 14.31818 MHz = 19.56 us
--        E =  16 / 14.31818 MHz =  1.12 us
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_controller is
  
  port (
    CLK_14M    : in  std_logic;	     -- 14.31818 MHz master clock
    nVIDEO		: in std_logic;
    COLOR_LINE : in std_logic;
    CBL			: in std_logic;

	SRAM_nWE	: out std_logic;
	SRAM_nOE 	: out std_logic;
	SRAM_nCE 	: out std_logic;
	SRAM_addr	: out unsigned(8 downto 0);
	SRAM_data	: inout unsigned(3 downto 0);
	 
    VGA_HS     : out std_logic;             -- Active low
    VGA_VS     : out std_logic;             -- Active low
    VGA_R      : out std_logic_vector(1 downto 0);
    VGA_G      : out std_logic_vector(1 downto 0);
    VGA_B      : out std_logic_vector(1 downto 0);
	 
	 MODE			: in std_logic
    );
  
end vga_controller;

architecture rtl of vga_controller is

--GE
signal HBL		: std_logic := '0';
signal VBL		: std_logic := '0';

signal SRAM_rd_data	: unsigned(5 downto 0);
signal SRAM_wr_data	: unsigned(3 downto 0);
signal SRAM_nWEi	: std_logic;
signal SRAM_nOEi 	: std_logic;
signal SRAM_nCEi 	: std_logic;

signal RCOL : std_logic_vector(1 downto 0) := "00";
signal GCOL : std_logic_vector(1 downto 0) := "00";
signal BCOL : std_logic_vector(1 downto 0) := "00";

signal R : std_logic_vector(1 downto 0);
signal G : std_logic_vector(1 downto 0);
signal B : std_logic_vector(1 downto 0);

signal PIXPAT : unsigned(3 downto 0);
signal RAMPIXPAT : unsigned(5 downto 0);
signal COLPAT : unsigned(3 downto 0);
signal TEXT : std_logic;

  signal ram_write_addr : unsigned(8 downto 0);
  signal ram_we : std_logic;
  signal ram_read_addr : unsigned(8 downto 0);

  signal hcount : unsigned(9 downto 0);
  signal hcount2 : unsigned(9 downto 0);
  --GE signal vcount : unsigned(5 downto 0);
  signal vcount : unsigned(6 downto 0);
  
  signal even_line : std_logic := '0';
  signal hactive : std_logic;

  constant VGA_SCANLINE : integer := 456;  -- Must be 456 (set by the Apple)
  
  constant VGA_HSYNC : integer := 54;
  constant VGA_BACK_PORCH : integer := 66;
  constant VGA_ACTIVE : integer := 282;  -- Must be 280 (set by the Apple)
  constant VGA_FRONT_PORCH : integer := 54;

  -- VGA_HSYNC + VGA_BACK_PORCH + VGA_ACTIVE + VGA_FRONT_PORCH = VGA_SCANLINE

  --GE (org) constant VBL_TO_VSYNC : integer := 33;
  --GE constant VBL_TO_VSYNC : integer := 80;
  constant VBL_TO_VSYNC : integer := 55;
  constant VGA_VSYNC_LINES : integer := 3;

  signal VGA_VS_I, VGA_HS_I : std_logic;

  signal video_active : std_logic;
  signal vbl_delayed : std_logic;
  signal color_line_delayed_1, color_line_delayed_2 : std_logic;

  --GE 10/02/2009
  signal cbl_last : std_logic;
  signal cbl_count : unsigned(9 downto 0);

begin

  --GE 10/02/2009
  blank_sep2 : process(CLK_14M, CBL, cbl_last, cbl_count)
  begin
    if falling_edge(CLK_14M) then
      cbl_count <= cbl_count + 1;
      cbl_last <= CBL;
      if (cbl_last = '0' and CBL = '1') then
        cbl_count <= "1000100101"; -- 549
      end if;
      if (cbl_count = 911) then
        cbl_count <= (others => '0');
        VBL <= CBL;
        color_line_delayed_2 <= color_line_delayed_1;
        color_line_delayed_1 <= COLOR_LINE;
        vbl_delayed <= VBL;
        if VBL = '1' then
          even_line <= '0';
          vcount <= vcount + 1;
        else
          vcount <= (others => '0');
          even_line <= not even_line;
        end if;      
      end if;
      if (cbl_count >= 549) and (cbl_count <= 899) then
        HBL <= '1';
      else
        HBL <= '0';
      end if;
    end if;
  end process;
  hcount <= cbl_count;

  hsync_gen : process (CLK_14M)
  begin
    if falling_edge(CLK_14M) then
      if hcount = VGA_ACTIVE + VGA_FRONT_PORCH or
        hcount = VGA_SCANLINE + VGA_ACTIVE + VGA_FRONT_PORCH then
        VGA_HS_I <= '0';
      elsif hcount = VGA_ACTIVE + VGA_FRONT_PORCH + VGA_HSYNC or
        hcount = VGA_SCANLINE + VGA_ACTIVE + VGA_FRONT_PORCH + VGA_HSYNC then
        VGA_HS_I <= '1';
      end if;

      if hcount = VGA_SCANLINE - 1 or
        hcount = VGA_SCANLINE + VGA_SCANLINE - 1 then
        hactive <= '1';
      elsif hcount = VGA_ACTIVE or
        hcount = VGA_ACTIVE + VGA_SCANLINE then
        hactive <= '0';
      end if;
    end if;
  end process hsync_gen;

  VGA_HS <= VGA_HS_I;

  vsync_gen : process (CLK_14M)
  begin
    if falling_edge(CLK_14M) then
      if vcount = VBL_TO_VSYNC then
        VGA_VS_I <= '0';
      elsif vcount = VBL_TO_VSYNC + VGA_VSYNC_LINES then
        VGA_VS_I <= '1';
      end if;
    end if;
  end process vsync_gen;

  VGA_VS <= VGA_VS_I;

  -- Shift in the incoming bits to reconstruct four-bit groups
  input_shift_register : process (CLK_14M)
  begin
    if falling_edge(CLK_14M) then
      PIXPAT <= PIXPAT(2 downto 0) & nVIDEO;
    end if;
  end process input_shift_register;

  hcount2 <= hcount - VGA_SCANLINE;

  ram_read_addr <=
    even_line & hcount(8 downto 1) when hcount < VGA_SCANLINE else
    even_line & hcount2(8 downto 1);
  
  ram_write_addr <= (not even_line) & hcount(9 downto 2);
  ram_we <= '1' when hcount(1 downto 0) = "00" else '0';

  video_active <= hactive and not vbl_delayed;

  -- RGB values from Linards Ticmanis,
  -- http://newsgroups.derkeiler.com/Archive/Comp/comp.sys.apple2/2005-09/msg00534.html

colorgen: process(COLPAT)
begin
	case COLPAT is
	when "1110" => -- 1 - 0x90 17 40
		RCOL <= "10";
		GCOL <= "00";
		BCOL <= "01";
	when "0111" => -- 2 - 0x40 2c a5
		RCOL <= "01";
		GCOL <= "00";
		BCOL <= "10";
	when "0110" => -- 3 - 0xd0 43 e5
		RCOL <= "11";
		GCOL <= "01";
		BCOL <= "11";
	when "1011" => -- 4 - 0x00 69 40
		RCOL <= "00";
		GCOL <= "01";
		BCOL <= "01";
	when "1010" => -- 5 - 0x80 80 80
		RCOL <= "10";
		GCOL <= "10";
		BCOL <= "10";
	when "0011" => -- 6 - 0x2f 95 e5 
		RCOL <= "00";
		GCOL <= "10";
		BCOL <= "11";
	when "0010" => -- 7 - 0xbf ab ff
		RCOL <= "11";
		GCOL <= "10";
		BCOL <= "11";
	when "1101" => -- 8 - 0x40 54 00
		RCOL <= "01";
		GCOL <= "01";
		BCOL <= "00";
	when "1100" => -- 9 - 0xd0 6a 1a 
		RCOL <= "11";
		GCOL <= "01";
		BCOL <= "00";
	when "0101" => -- 10 - 0x80 80 80
		RCOL <= "01";
		GCOL <= "01";
		BCOL <= "01";
	when "0100" => -- 11 - 0xff 96 bf
		RCOL <= "11";
		GCOL <= "10";
		BCOL <= "11";
	when "1001" => -- 12 - 0x2f bc 1a 
		RCOL <= "00";
		GCOL <= "11";
		BCOL <= "00";
	when "1000" => -- 13 - 0xbf d3 5a
		RCOL <= "11";
		GCOL <= "11";
		BCOL <= "01";
	when "0001" => -- 14 - 0x6f e8 bf
		RCOL <= "01";
		GCOL <= "11";
		BCOL <= "11";
	when "0000" => -- 15 - 0xff ff ff 
		RCOL <= "11";
		GCOL <= "11";
		BCOL <= "11";
	when others => -- 0 - 0x00 00 00
		RCOL <= "00";
		GCOL <= "00";
		BCOL <= "00";
          end case;    
end process;

TEXT <= '1' when hcount(0) = '0' and CLK_14M = '0' and RAMPIXPAT(3) = '0'
	else '1' when hcount(0) = '0' and CLK_14M = '1' and RAMPIXPAT(2) = '0'
	else '1' when hcount(0) = '1' and CLK_14M = '0' and RAMPIXPAT(1) = '0'
	else '1' when hcount(0) = '1' and CLK_14M = '1' and RAMPIXPAT(0) = '0'
	else '0';

COLPAT <= RAMPIXPAT(3 downto 0) when hcount(0) = '1'
	else RAMPIXPAT(3 downto 2) & RAMPIXPAT(5 downto 4);

--GE
SRAM_addr <= ram_read_addr when hcount(0) = '1' else ram_write_addr;
SRAM_nWEi <= not ram_we;
SRAM_nOEi <= '0' when hcount(0) = '1' else '1';
SRAM_nCEi <= CLK_14M;
process(CLK_14M)
begin
	if rising_edge(CLK_14M) and SRAM_nOEi = '0' then
		SRAM_rd_data <= SRAM_rd_data(1 downto 0) & SRAM_data;
	end if;
end process;
process(CLK_14M)
begin
	if falling_edge(CLK_14M) then
		RAMPIXPAT <= SRAM_rd_data;
	end if;
end process;

SRAM_wr_data <= PIXPAT;
SRAM_data <= SRAM_wr_data when SRAM_nCEi = '0' and SRAM_nWEi = '0' else "ZZZZ";

SRAM_nCE <= SRAM_nCEi;
SRAM_nOE <= SRAM_nOEi;
SRAM_nWE <= SRAM_nWEi;

R <= RCOL when video_active = '1' and color_line_delayed_2 = '1' 
	else TEXT & TEXT when video_active = '1' and color_line_delayed_2 = '0' 
	else "00";
G <= GCOL when video_active = '1' and color_line_delayed_2 = '1' 
	else TEXT & TEXT when video_active = '1' and color_line_delayed_2 = '0' 
	else "00";
B <= BCOL when video_active = '1' and color_line_delayed_2 = '1' 
	else TEXT & TEXT when video_active = '1' and color_line_delayed_2 = '0' 
	else "00";
VGA_R <= R when MODE = '1' else "00";
VGA_G <= G when MODE = '1' else TEXT & TEXT when video_active = '1' else "00";
VGA_B <= B when MODE = '1' else "00";

end rtl;
