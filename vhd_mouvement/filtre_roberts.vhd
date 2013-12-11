library IEEE;
use IEEE.std_logic_1164.all;
--use IEEE.numeric_std.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_signed.all;

entity filtre_roberts is
		generic (
		address_size : integer
		);
	    port (
		CLK				: in std_logic;
		RESET			: in std_logic;
		pix12_address	: out std_logic_vector(address_size-1 downto 0);
		pix12_ram		: in std_logic_vector(7 downto 0);
		read_write		: out std_logic;
		iY				: in std_logic_vector(7 downto 0);
		oY				: out std_logic_vector(7 downto 0);
		in_active_area	: in std_logic
		);
end entity filtre_roberts; -- filtre_roberts



architecture arch of filtre_roberts is

--types
subtype addr_type is std_logic_vector(address_size-1 downto 0);
subtype pix_type is std_logic_vector(7 downto 0);
subtype grad_type is std_logic_vector(15 downto 0);

--signals
signal address_curr, address_next 	: addr_type;
signal synchro_curr, synchro_next 	: std_logic;
signal oY_curr, oY_next 			: pix_type;
signal rw_curr, rw_next				: std_logic;


begin


--concurent
	oY <= oY_curr;
	pix12_address <= address_curr;
	read_write <= rw_curr ;
	
	
--process seq	
	process_seq:process(CLK, in_active_area)	-- clk à 27 MHz <=> 2 périodes en 1 pixel 
	begin	
	if (clk = '1' and clk'event) then 	
		if RESET ='0' then -- reset actif
			address_curr <= (others => '0');
			synchro_curr <= '0';
			oY_curr <= (others => '0');
			rw_curr <= '0';
		else
			address_curr <= address_next;
			synchro_curr <= synchro_next;
			oY_curr <= oY_next;
			rw_curr <= rw_next;
		end if;	
	end if;			
	end process process_seq;


--process comb
	process_roberts : process( in_active_area, iY, pix12_ram, synchro_curr )
		variable pix11, pix21 : pix_type := (others => '0');
		variable gradH, gradV : grad_type := (others => '0');
		--variable pixout : pix_type := (others => '0');
		
	begin
		if in_active_area = '1' then
			if synchro_curr = '1' then
				--oY_next <= pix_type(unsigned(iY) + unsigned(pix12_ram) - unsigned(pix11) - unsigned(pix21));
				gradH := (iY+pix12_ram-pix11-pix21)*(iY+pix12_ram-pix11-pix21);
				gradV := (-iY+pix12_ram+pix11-pix21)*(-iY+pix12_ram+pix11-pix21);
				--oY_next <= (iY+pix12_ram-pix11-pix21)*(iY+pix12_ram-pix11-pix21)+(-iY+pix12_ram+pix11-pix21)*(-iY+pix12_ram+pix11-pix21);
				pix11 := pix12_ram;
				rw_next <= '1';
			else
				--oY_next <= pixout;
				oY_next <= gradH(7 downto 0) + gradV(7 downto 0);
				pix21 := iY;
				address_next <= address_curr + 1;
				rw_next <= '0';
			end if;
			synchro_next <= not(synchro_curr);
		else
			synchro_next <= '0';
			address_next <= (others => '0');
			oY_next <= iY;	-- no treatment
		end if;	
	end process process_roberts; -- process_diff
	
end architecture arch; -- arch


