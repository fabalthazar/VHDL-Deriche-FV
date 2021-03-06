library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity filtre_video is
	generic (
			size        : integer := 8;  -- taille de la sous-fenetre = 2**size pixels
			size_RAM    : integer := 9;
			gamma       : std_logic_vector(2 downto 0) := "100"
			);
    port (
			--horloge et reset
			CLK			: in std_logic; -- clock � 54 MHz
			RESET 		: in std_logic; -- reset � 0
			-- flux video � 27 MHz
			-- synchro
			VGA_X :	in std_logic_vector(10 downto 0); -- compteur pixels
			VGA_Y :	in std_logic_vector(10 downto 0); -- compteur lignes
			-- entr�e
			iY : 	in std_logic_vector(7 downto 0); -- flux video entrant : luminance
			iCb : 	in std_logic_vector(7 downto 0); -- flux video entrant : chrominance bleu
			iCr : 	in std_logic_vector(7 downto 0); -- flux video entrant : chrominance rouge
			-- sortie
			oY	: 	out std_logic_vector(7 downto 0); -- flux video sortant : luminance
			oCb	: 	out std_logic_vector(7 downto 0); -- flux video sortant : chrominance bleu
			oCr	: 	out std_logic_vector(7 downto 0); -- flux video sortant : chrominance rouge
			--switch D2E
			switch			: in std_logic_vector(17 downto 0);		-- � connecter � DPDT_SW;
			-- SRAM interfaces
			address_SRAM 	: out std_logic_vector(17 downto 0); 	-- � connecter � SRAM_ADDR
			data_SRAM		: inout std_logic_vector(15 downto 0);  -- � connecter � SRAM_DQ
			write_enable 	: out std_logic; 						-- � connecter � SRAM_WE_N
			read_enable 	: out std_logic; 						-- � connecter � SRAM_OE_N
			chip_enable 	: out std_logic;						-- � connecter � SRAM_CE_N
			high_mask 		: out std_logic ; 						-- � connecter � SRAM_UB_N
			low_mask 		: out std_logic
			);
end entity filtre_video;


architecture A of filtre_video is

component module_fenetrage
	generic (
			size			: integer := 8
			);
	port (CLK				: in std_logic;
			VGA_X 			:	in std_logic_vector(10 downto 0);
			VGA_Y 			:	in std_logic_vector(10 downto 0);
			iY 				: 	in std_logic_vector(7 downto 0);
			oY				: 	out std_logic_vector(7 downto 0);
			in_active_area 	:	out std_logic;
			X_cpt			:	out std_logic_vector(10 downto 0);
			Y_cpt			:	out std_logic_vector(10 downto 0)
		);
end component;

component filtre_roberts is
    generic (
        address_size    : integer := 8
    );
    port (
        CLK             : in std_logic;
        RESET           : in std_logic;
        iY              : in std_logic_vector(7 downto 0);
        oY              : inout std_logic_vector(7 downto 0);
        in_active_area  : in std_logic
    );
end component;

component module_lissage is
	generic (
	    address_size    : integer := 8;
		gamma           : std_logic_vector(2 downto 0) := "100"
    );
    port (
        CLK             : in std_logic;
        RESET           : in std_logic;
        iY              : in std_logic_vector(7 downto 0);
        oY              : inout std_logic_vector(7 downto 0);
        in_active_area  : in std_logic
    );
end component;

--signaux flux video
signal sig_Y1			: std_logic_vector(7 downto 0);
signal sig_Y2			: std_logic_vector(7 downto 0);
signal sig_Y3			: std_logic_vector(7 downto 0);

--signaux de synchro module fenetrage
signal Y_cpt			: std_logic_vector(10 downto 0);
signal X_cpt 			: std_logic_vector(10 downto 0);
signal in_active_area 	: std_logic;

--signaux debug
signal threshold		: std_logic_vector(7 downto 0);

begin
    u_1: module_fenetrage
    generic map(
        size => size
    )
    port map(
        CLK => CLK,
        VGA_X => VGA_X,
        VGA_Y => VGA_Y,
        iY	=> iY,
        oY	=> sig_Y1,
        in_active_area => in_active_area,
        X_cpt => X_cpt,
        Y_cpt => Y_cpt
    );

    u_2: filtre_roberts
    generic map(
        address_size => size_RAM
    )
    port map(
        CLK => CLK,
        RESET => RESET,
        iY => sig_Y3,
        oY => sig_Y2,
        in_active_area => in_active_area
    );

    u_3: module_lissage
    generic map(
        address_size => size_RAM,
        gamma => gamma
    )
    port map(
        CLK => CLK,
        RESET => RESET,
        iY => sig_Y1,
        oY => sig_Y3,
        in_active_area => in_active_area
    );

	--concurrent
	threshold <= switch(17 downto 10);
	oCb <= X"80";
	oCr <= X"80";

	--process
	process_affichage : process( switch, iY, sig_Y1, sig_Y2, sig_Y3)
	begin
		case( switch(4 downto 0) ) is
			when "00000" => oY <= iY; -- avant fenetrage
			when "00001" => oY <= sig_Y1; -- apr�s fenetrage
			when others  => oY <= sig_Y2;  -- apr�s Roberts
		end case ;
	end process ; -- process_affichage

end architecture A;

