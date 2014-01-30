library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity module_lissage is
    generic(
        address_size    : integer := 8;
        gamma           : std_logic_vector(2 downto 0) := "100"
    );
    port(
        CLK             : in std_logic;
        RESET           : in std_logic;
        iY              : in std_logic_vector(7 downto 0);
        oY              : inout std_logic_vector(7 downto 0);
        in_active_area  : in std_logic
    );
end entity module_lissage;


architecture arch of module_lissage is

component memoire_ligne is
    generic (
        address_size    : integer := 8;
        word_size       : integer := 8
    );
    port (
        CLK             : in std_logic;
        address         : in std_logic_vector(address_size-1 downto 0);
        data_in         : in std_logic_vector(word_size-1 downto 0);
        data_out        : out std_logic_vector(word_size-1 downto 0);
        read_write      : in std_logic
    );
end component;

--types
subtype addr_type is std_logic_vector(address_size-1 downto 0);
subtype pix_type is unsigned(7 downto 0);

--signals
signal synchro_curr, synchro_next                                                                   : std_logic;
signal R1_causal_curr, R1_causal_next, R2_causal_curr, R2_causal_next                               : pix_type;
signal R1_anticausal_curr, R1_anticausal_next, R2_anticausal_curr, R2_anticausal_next               : pix_type;
signal address_ligne1, address_ligne2                                                               : addr_type;
signal address_causal_curr, address_causal_next, address_anticausal_curr, address_anticausal_next   : addr_type;
signal in_ligne1, out_ligne1, in_ligne2, out_ligne2                                                 : pix_type;
signal in_causal, out_causal, in_anticausal, out_anticausal                                         : pix_type;
signal rw_ligne1, rw_ligne2                                                                         : std_logic;
signal rw_causal, rw_anticausal                                                                     : std_logic;
signal oY_next                                                                                      : pix_type;
signal switch_curr, switch_next                                                                     : std_logic;

begin

    ligne1: memoire_ligne  -- mémoire ligne des pixels lissés causalement
    generic map(
        address_size => address_size,
        word_size => pix_type'length
    )
    port map(
        CLK => CLK,
        address => address_ligne1,
        data_in => std_logic_vector(in_ligne1),
        unsigned(data_out) => out_ligne1,
        read_write => rw_ligne1
    );
    
    ligne2: memoire_ligne  -- mémoire ligne des pixels lissés anticausalement
    generic map(
        address_size => address_size,
        word_size => pix_type'length
    )
    port map(
        CLK => CLK,
        address => address_ligne2,
        data_in => std_logic_vector(in_ligne2),
        unsigned(data_out) => out_ligne2,
        read_write => rw_ligne2
    );
    
    --concurent

    --process seq
    process_seq: process(CLK)  -- CLK à 27 MHz <=> 2 périodes par pixel
    begin
        if CLK = '1' and CLK'event then
            if RESET = '0' then  -- reset actif
                address_causal_curr <= (others => '0');
                address_anticausal_curr <= (others => '1');
                synchro_curr <= '0';
                oY <= iY;
                switch_curr <= '0';
                R1_causal_curr <= (others => '0');
                R2_causal_curr <= (others => '0');
                R1_anticausal_curr <= (others => '0');
                R2_anticausal_curr <= (others => '0');
            else
                -- mise à jour des registres
                oY <= std_logic_vector(oY_next);
                synchro_curr <= synchro_next;
                switch_curr <= switch_next;
                R1_causal_curr <= R1_causal_next;
                R2_causal_curr <= R2_causal_next;
                R1_anticausal_curr <= R1_anticausal_next;
                R2_anticausal_curr <= R2_anticausal_next;
                address_causal_curr <= address_causal_next;
                address_anticausal_curr <= address_anticausal_next;
            end if;
        end if;
    end process process_seq;

    --process comb
    process_comb_causal: process(oY, switch_curr, in_causal, in_anticausal, out_ligne1, out_ligne2, rw_anticausal, R1_causal_curr, R2_causal_curr, in_active_area, synchro_curr, out_anticausal, iY, address_causal_curr, address_anticausal_curr)
        
        variable terme1, terme2, terme3 : unsigned(13 downto 0);
        
    begin
        oY_next <= unsigned(oY);
        switch_next <= switch_curr;
        if (switch_curr = '0') then  -- switch des deux lignes
            in_ligne1 <= in_causal;
            in_ligne2 <= in_anticausal;
            out_anticausal <= out_ligne1;
            out_causal <= out_ligne2;
            rw_ligne1 <= rw_causal;
            rw_ligne2 <= rw_anticausal;
            address_ligne1 <= address_causal_curr;
            address_ligne2 <= address_anticausal_curr;
        else
            in_ligne2 <= in_causal;
            in_ligne1 <= in_anticausal;
            out_anticausal <= out_ligne2;
            out_causal <= out_ligne1;
            rw_ligne2 <= rw_causal;
            rw_ligne1 <= rw_anticausal;
            address_ligne2 <= address_causal_curr;
            address_ligne1 <= address_anticausal_curr;
        end if;
        -- affectation des valeurs par défaut (évite les états indéterminés et les latch)
        synchro_next <= '0';
        in_causal <= (others => '0');
        rw_causal <= '0';
        address_causal_next <= (others => '0');
        R1_causal_next <= R1_causal_curr;
        R2_causal_next <= R2_causal_curr;
        if in_active_area = '1' then
            if synchro_curr = '0' then
                oY_next <= out_anticausal;
                terme1 := (8-unsigned(gamma))*(8-unsigned(gamma))*unsigned(iY);
                terme2 := 2*unsigned(gamma)*R1_causal_curr;
                terme3 := unsigned(gamma)*unsigned(gamma)*R2_causal_curr;
                in_causal <= terme1(13 downto 6) + terme2(10 downto 3) - terme3(13 downto 6);
                
                R2_causal_next <= R1_causal_curr;
                R1_causal_next <= in_causal;
                rw_causal <= '1';
                address_causal_next <= address_causal_curr;  -- inchangée
            else
                if (address_causal_curr = "1111") then  -- changer en "011111111" en synthèse sur carte !
                    switch_next <= not(switch_curr);
                end if;
                address_causal_next <= std_logic_vector(unsigned(address_causal_curr) + 1);
            end if;
            synchro_next <= not(synchro_curr);
        else
            R1_causal_next <= (others => '0');
            R2_causal_next <= (others => '0');
        end if;
    end process process_comb_causal;  -- process_comb_causal
    
    
    process_comb_anticausal: process(R1_anticausal_curr, R2_anticausal_curr, in_active_area, synchro_curr, out_causal, in_anticausal, address_anticausal_curr)

        variable terme1, terme2, terme3 : unsigned(13 downto 0);

    begin
        -- affectation des valeurs par défaut (évite les états indéterminés et les latch)
        in_anticausal <= (others => '0');
        rw_anticausal <= '0';
        address_anticausal_next <= (others => '1');
        R1_anticausal_next <= R1_anticausal_curr;
        R2_anticausal_next <= R2_anticausal_curr;
        if in_active_area = '1' then
            if synchro_curr = '0' then
                terme1 := (8-unsigned(gamma))*(8-unsigned(gamma))*out_causal;
                terme2 := 2*unsigned(gamma)*R1_anticausal_curr;
                terme3 := unsigned(gamma)*unsigned(gamma)*R2_anticausal_curr;
                in_anticausal <= terme1(13 downto 6) + terme2(10 downto 3) - terme3(13 downto 6);
                
                R2_anticausal_next <= R1_anticausal_curr;
                R1_anticausal_next <= in_anticausal;
                rw_anticausal <= '1';
                address_anticausal_next <= address_anticausal_curr;  -- inchangée
            else
                address_anticausal_next <= std_logic_vector(unsigned(address_anticausal_curr) - 1);
            end if;
        else
            R1_anticausal_next <= (others => '0');
            R2_anticausal_next <= (others => '0');
        end if;
    end process process_comb_anticausal;  -- process_comb_anticausal

end architecture arch;  -- arch

