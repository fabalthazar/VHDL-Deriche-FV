library IEEE;
use IEEE.std_logic_1164.all;
--use IEEE.numeric_std.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_signed.all;

entity filtre_roberts is
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
end entity filtre_roberts;


architecture arch of filtre_roberts is

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
subtype pix_type is std_logic_vector(7 downto 0);
subtype spix_type is std_logic_vector(9 downto 0);  -- 10 bits = 8+1 (ajout du bit de signe) +1 (GradX_tmp peut valoir au max 510=2*255)
subtype grad_type is std_logic_vector(19 downto 0);  -- 20 bits = 2*10 (car gardient = carré de spix_type) -1 (positif) +1 (somme de GradH et GradV)

--signals
signal oY_next                                                  : pix_type;
signal address_curr, address_next                               : addr_type;
signal synchro_curr, synchro_next                               : std_logic;
signal pix_12_ram                                               : pix_type;
signal pix_11_curr, pix_21_curr, pix_11_next, pix_21_next       : pix_type;
signal rw_pix, rw_grad                                          : std_logic;
signal Grad_13_ram, Grad_23_ram, Grad_33_curr, Grad_33_next     : grad_type;
signal Grad_11_curr, Grad_12_curr, Grad_11_next, Grad_12_next   : grad_type;
signal Grad_21_curr, Grad_22_curr, Grad_21_next, Grad_22_next   : grad_type;
signal Grad_31_curr, Grad_32_curr, Grad_31_next, Grad_32_next   : grad_type;
signal GradH_curr, GradV_curr, GradH_next, GradV_next           : spix_type;

-- Génère le contour blanc si gradient du milieu supérieur aux deux autres
function gen_contour(Grad1, Grad2, Grad3 : grad_type) return pix_type is
    variable contour : pix_type := (others => '0');
begin
    if (Grad2 > Grad1 and Grad2 > Grad3) then
        contour := (others => '1');  -- pixel blanc
    else
        contour := "00010000";  -- pixel noir
    end if;
    return contour;
end function gen_contour;

begin

    u_1: memoire_ligne  -- mémoire ligne de pixels
    generic map(
        address_size => address_size,
        word_size => pix_type'length
    )
    port map(
        CLK => CLK,
        address => address_curr,
        data_in => iY,
        data_out => pix_12_ram,
        read_write => rw_pix
    );

    u_2: memoire_ligne  -- mémoire ligne des gradients Grad_1X
    generic map(
        address_size => address_size,
        word_size => grad_type'length
    )
    port map(
        CLK => CLK,
        address => address_curr,
        data_in => Grad_23_ram,
        data_out => Grad_13_ram,
        read_write => rw_grad
    );

    u_3: memoire_ligne  -- mémoire ligne des gradients Grad_2X
    generic map(
        address_size => address_size,
        word_size => grad_type'length
    )
    port map(
        CLK => CLK,
        address => address_curr,
        data_in => Grad_33_curr,
        data_out => Grad_23_ram,
        read_write => rw_grad
    );

    --concurent

    --process seq
    process_seq:process(CLK)  -- CLK à 27 MHz <=> 2 périodes par pixel
    begin
        if CLK = '1' and CLK'event then
            if RESET = '0' then  -- reset actif
                address_curr <= (others => '0');
                synchro_curr <= '0';
                oY <= iY;
                
                pix_11_curr <= (others => '0');
                pix_21_curr <= (others => '0');
                
                GradH_curr <= (others => '0');
                GradV_curr <= (others => '0');
                Grad_11_curr <= (others => '0');
                Grad_12_curr <= (others => '0');
                Grad_21_curr <= (others => '0');
                Grad_22_curr <= (others => '0');
                Grad_31_curr <= (others => '0');
                Grad_32_curr <= (others => '0');
                Grad_33_curr <= (others => '0');
            else  -- mise à jour des registres
                address_curr <= address_next;
                synchro_curr <= synchro_next;
                
                pix_11_curr <= pix_11_next;
                pix_21_curr <= pix_21_next;
                
                Grad_11_curr <= Grad_11_next;
                Grad_12_curr <= Grad_12_next;
                Grad_21_curr <= Grad_21_next;
                Grad_22_curr <= Grad_22_next;
                Grad_31_curr <= Grad_31_next;
                Grad_32_curr <= Grad_32_next;
                Grad_33_curr <= Grad_33_next;
                
                oY <= oY_next;
            end if;
        end if;
    end process process_seq;

    --process comb
    process_roberts : process(oY, in_active_area, synchro_curr, pix_11_curr, pix_12_ram, pix_21_curr, iY, Grad_33_curr, Grad_12_curr, Grad_13_ram, Grad_22_curr, Grad_23_ram, Grad_32_curr, Grad_31_curr, Grad_21_curr, Grad_11_curr, address_curr)

        variable spix_11, spix_12, spix_21, spix_22     : spix_type := (others => '0');
        variable GradH_tmp, GradV_tmp                   : spix_type := (others => '0');
        variable d0, d1, d2, d3                         : grad_type := (others => '0');

    begin

        -- affectation des valeurs par défaut (évite les états indéterminés et les latch)
        rw_pix <= '0';
        rw_grad <= '0';
        oY_next <= iY;  -- no treatment
        synchro_next <= '0';
        address_next <= (others => '0');
        pix_11_next <= pix_11_curr;  -- par défaut on ne touche pas au contenu des registres
        pix_21_next <= pix_21_curr;
        Grad_11_next <= Grad_11_curr;
        Grad_12_next <= Grad_12_curr;
        Grad_21_next <= Grad_21_curr;
        Grad_22_next <= Grad_22_curr;
        Grad_31_next <= Grad_31_curr;
        Grad_32_next <= Grad_32_curr;
        Grad_33_next <= Grad_33_curr;

        if in_active_area = '1' then
            if synchro_curr = '0' then
                spix_11 := "00" & pix_11_curr;  -- ajout du bit de signe +1 pour compléter la taille et permettre le calcul du gradient
                spix_12 := ("00" & pix_12_ram);
                spix_21 := ("00" & pix_21_curr);
                spix_22 := ("00" & iY);
                GradH_tmp :=  spix_22 + spix_12 - spix_11 - spix_21;
                GradV_tmp := -spix_22 + spix_12 + spix_11 - spix_21;
                Grad_33_next <= std_logic_vector(GradH_tmp*GradH_tmp) + std_logic_vector(GradV_tmp*GradV_tmp);
                
                pix_11_next <= pix_12_ram;
                pix_21_next <= iY;
                rw_pix <= '1';  -- on sauvegarde le pixel d'entrée en RAM maintenant car on ne sait pas quand arrive le suivant
                address_next <= address_curr;  -- inchangée
                oY_next <= oY;  -- inchangée
            else
                Grad_11_next <= Grad_12_curr;
                Grad_12_next <= Grad_13_ram;
                Grad_21_next <= Grad_22_curr;
                Grad_22_next <= Grad_23_ram;
                Grad_31_next <= Grad_32_curr;
                Grad_32_next <= Grad_33_curr;
                
                d0 := abs(Grad_13_ram-Grad_31_curr);
                d1 := abs(Grad_23_ram-Grad_21_curr);
                d2 := abs(Grad_33_curr-Grad_11_curr);
                d3 := abs(Grad_12_curr-Grad_32_curr);
                
                -- génération du contour
                if d0>d1 then
                    if d0>d2 then
                        if d0>d3 then
                            --d0
                            oY_next <= gen_contour(Grad_31_curr, Grad_22_curr, Grad_13_ram);
                        else
                            --d3
                            oY_next <= gen_contour(Grad_12_curr, Grad_22_curr, Grad_32_curr);
                        end if;
                    elsif d2>d3 then
                        --d2
                        oY_next <= gen_contour(Grad_11_curr, Grad_22_curr, Grad_33_curr);
                    else
                        --d3
                        oY_next <= gen_contour(Grad_12_curr, Grad_22_curr, Grad_32_curr);
                    end if;
                elsif d1>d2 then
                    if d1>d3 then
                        --d1
                        oY_next <= gen_contour(Grad_21_curr, Grad_22_curr, Grad_23_ram);
                    else
                        --d3
                        oY_next <= gen_contour(Grad_12_curr, Grad_22_curr, Grad_32_curr);
                    end if;
                elsif d2>d3 then
                    --d2
                    oY_next <= gen_contour(Grad_11_curr, Grad_22_curr, Grad_33_curr);
                else
                    --d3
                    oY_next <= gen_contour(Grad_12_curr, Grad_22_curr, Grad_32_curr);
                end if;
                rw_grad <= '1';  -- sauvegarde des gradients en RAM
                address_next <= address_curr + 1;
            end if;
            synchro_next <= not(synchro_curr);
        end if;
    end process process_roberts;  -- process_roberts

end architecture arch;  -- arch

