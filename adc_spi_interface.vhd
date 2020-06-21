--! File: adc_spi_inteface.vhd
--! ***********************************************************************
--!  Project: Grad660
--! ***********************************************************************
--! *
--! *
--! * Author: Stephen Okuribido
--! * 
--! * Date: 14/03/2018
--! *
--! ***********************************************************************
--! * Description: 
--! * SPI interface to the Mag ADCs. It acquires the combined 72bit value 
--! * from the daisy-chained ADCs and then splits it into 3 24bit chunks 
--! * of data and outputs them.
--! * It also generates the sync signal and the master clock for ADCs.
--! ***********************************************************************
--! * Copyright (c) 2018 by BARINGTON INSTRUMENTS, Witney, UK
--! ***********************************************************************


LIBRARY ieee;
USE ieee.std_logic_1164.all; 
USE ieee.numeric_std.all;

entity adc_spi_interface is 
port(
        reset       : in std_logic;                      -- Module reset
        sys_clk     : in std_logic;                      -- Main clock
        adc_drdy_n  : in std_logic;                      -- Data ready for ADC B
        adc_sync_n  : out std_logic;                     -- Synchronization and Power-Down for ADC B
        adc_cs      : out std_logic;                     -- Chip Select Input for ADC B
        adc_sclk    : out std_logic;                     -- Serial Clock Input for ADC B
        adc_clk     : out std_logic;                     -- Master Clock Input for ADC B
        adc_data    : in std_logic;                      -- Serial Data Output of ADC B
        x_drdy      : out std_logic;                     -- Data ready signal for X ADC data
        y_drdy      : out std_logic;                     -- Data ready signal for Y ADC data
        z_drdy      : out std_logic;                     -- Data ready signal for Z ADC data
        data_b      : out std_logic_vector(23 downto 0)  -- Data output stream for ADCs B
    );
end adc_spi_interface;

architecture behavior of adc_spi_interface is
type mini_state is (s0, s1, s2);
signal shot_gen_cs,shot_gen_ns : mini_state;

type chip_sel_state is (s0, s1, s2, s3, s4);
signal chip_sel_cs, chip_sel_ns : chip_sel_state;

signal adc_clk_strb    : std_logic;
signal adc_ready_dd    : std_logic;
signal adc_ready_strb  : std_logic;
signal x_pre_drdy      : std_logic;
signal x_pre_drdy_d    : std_logic;
signal x_pre_drdy_dd   : std_logic;
signal y_pre_drdy      : std_logic;
signal y_pre_drdy_d    : std_logic;
signal y_pre_drdy_dd   : std_logic;
signal z_pre_drdy      : std_logic;
signal z_pre_drdy_d    : std_logic;
signal z_pre_drdy_dd   : std_logic;
signal pre_adc_cs      : std_logic;
signal sclk_counter    : std_logic_vector(6 downto 0);
signal clk_div_counter : std_logic_vector(4 downto 0);
signal clk_div_cnt_reg : std_logic_vector(4 downto 0);
signal clk_div_counter_3_d : std_logic;
signal shift_en_b      : std_logic;
signal shift_en_ba     : std_logic;
signal regb_en         : std_logic;
signal regba_en        : std_logic;
signal reg_b           : std_logic;
signal reg_ba          : std_logic;
signal zero_flg        : std_logic;
signal sreg_b          : std_logic_vector(23 downto 0);
signal sreg_ba         : std_logic_vector(23 downto 0);
signal one_shot_cnt    : unsigned(7 downto 0);
signal x_data_rdy_strb : std_logic;
signal y_data_rdy_strb : std_logic;
signal z_data_rdy_strb : std_logic;
signal adc_drdy_sync   : std_logic;
signal sclk_en         : std_logic;
signal adc_sclk_b_reg  : std_logic;
signal adc_sclk_ba_reg : std_logic;
signal sclk_re         : std_logic;
signal sclk_fe         : std_logic;
signal adc_sclk_reg    : std_logic;
signal adc_sclk_reg_d  : std_logic;
signal pre_sclk_re     : std_logic;
signal pre_sclk_fe     : std_logic;
signal pre_adc_clk_togle     : std_logic;
signal pre_adc_clk_b   : std_logic;
signal pre_adc_clk_ba  : std_logic;
signal pre_adc_clk_toggle : std_logic;

constant adc_mclk_max_val : std_logic_vector(4 downto 0) := "11000";

begin


adc_sclk  <= adc_sclk_reg and sclk_en;


---------------------------------------


-------------------------------------------
--          adc clock gen                --
-- generates adc spi clocks and adc master
-- clocks
-------------------------------------------
clk_div_count : process(reset, sys_clk)
begin
    if reset = '1' then
	    pre_adc_clk_b <= '0';
		pre_adc_clk_ba <= '0';
        clk_div_counter <= (others => '0');
    elsif rising_edge(sys_clk) then
	    if clk_div_counter = adc_mclk_max_val then
		    clk_div_counter <= (others => '0');
		else
            clk_div_counter <= std_logic_vector(unsigned(clk_div_counter) + 1);
		end if;
		
    	clk_div_cnt_reg <=  clk_div_counter;
    
        if pre_adc_clk_toggle = '1' then
    	    pre_adc_clk_b <= not pre_adc_clk_b;
    	end if;
    	    
        if pre_adc_clk_toggle = '1' then
    	    pre_adc_clk_ba <= not pre_adc_clk_ba;
    	end if;
    end if;
	
end process;

pre_adc_clk_toggle <= '1' when clk_div_cnt_reg = adc_mclk_max_val else
                      '0';

adc_clk   <= pre_adc_clk_b;
-------------------------------------------


---------------------------------------
--        one shot signal gen        --
-- generates the adc sync signal
---------------------------------------
one_shot_cntr : process(reset, sys_clk)
begin
    if reset = '1' then
        clk_div_counter_3_d <= '0';
        one_shot_cnt <= (others => '0');
    elsif rising_edge(sys_clk) then
        clk_div_counter_3_d <= clk_div_counter(3);
        
        adc_clk_strb <= clk_div_counter_3_d and not clk_div_counter(3);
    
        if one_shot_cnt /= x"ff" and adc_clk_strb = '1' then
            one_shot_cnt <= one_shot_cnt + 1;
        end if;
    end if;
end process;

adc_sync_n <= '0' when one_shot_cnt = x"fe" or one_shot_cnt = x"fd" or one_shot_cnt = x"fc" else
               '1';
----------------------------------------


----------------------------------------
-- sclk clock counter
----------------------------------------
sclk_count : process(reset, sys_clk)
begin
    if reset = '1' then
        sclk_counter <= (others => '0');
    elsif rising_edge(sys_clk) then
        if adc_drdy_sync = '1'  then
            sclk_counter <= (others => '0');
        elsif adc_sclk_reg_d = '1' and adc_sclk_reg = '0' and chip_sel_cs = s4 then
            sclk_counter <= std_logic_vector(unsigned(sclk_counter) + 1);
        end if;
    end if;
end process;
----------------------------------------


----------------------------------------
-- chip select and strobe signals generation
----------------------------------------

-- comparator
----------------------------------------
zero_flg <= '1' when sclk_counter(2 downto 0) = "000" else
            '0';

x_pre_drdy <= '1' when sclk_counter(6 downto 0) = "0010111" else
              '0';

y_pre_drdy <= '1' when sclk_counter(6 downto 3) = "0110" and zero_flg = '1' else
              '0';
             
z_pre_drdy <= '1' when sclk_counter(6 downto 3) = "1001" and zero_flg = '1' else
              '0';
-- strobe gen
----------------------------------------              
process(sys_clk)
begin
    if falling_edge(sys_clk) then   
        
        x_pre_drdy_d <= x_pre_drdy;
        x_pre_drdy_dd <= x_pre_drdy_d;
        
        y_pre_drdy_d <= y_pre_drdy;
        y_pre_drdy_dd <= y_pre_drdy_d;
        
        z_pre_drdy_d <= z_pre_drdy;
        z_pre_drdy_dd <= z_pre_drdy_d;

        x_drdy <= x_data_rdy_strb;
        y_drdy <= y_data_rdy_strb;
        z_drdy <= z_data_rdy_strb;

        
    end if;
end process;

x_data_rdy_strb <= x_pre_drdy_dd and not x_pre_drdy_d;
y_data_rdy_strb <= not y_pre_drdy_dd and y_pre_drdy_d;
z_data_rdy_strb <= not z_pre_drdy_dd and z_pre_drdy_d;
              
adc_cs <= pre_adc_cs;
-------------------------------------------


-------------------------------------------
-- spi cycle controller
-------------------------------------------
chip_sel_sync : process(reset, sys_clk)
begin
    if reset = '1' then
        chip_sel_cs <= s0;
    elsif rising_edge(sys_clk) then
        chip_sel_cs <= chip_sel_ns;
    end if;
end process;

chip_selcomb : process(chip_sel_cs, sclk_counter, adc_drdy_sync, adc_sclk_reg_d, adc_sclk_reg)
begin
    case chip_sel_cs is
        when s0 =>
            if adc_drdy_sync = '1' then
                chip_sel_ns <= s1;
            else
                chip_sel_ns <= s0;
            end if;
        when s1 =>
            if adc_drdy_sync = '0' then
                chip_sel_ns <= s2;
            else
                chip_sel_ns <= s1;
            end if;
        when s2 =>
            chip_sel_ns <= s3;
        when s3 =>
            if adc_sclk_reg_d = '1' and adc_sclk_reg = '0' then
                chip_sel_ns <= s4;
            else
                chip_sel_ns <= s3;
            end if;
        when s4 =>
            if sclk_counter(6 downto 3) = "1001" then
                chip_sel_ns <= s0;
            else
                chip_sel_ns <= s4;
            end if;
        when others =>
            chip_sel_ns <= s0;
    end case;
end process;

sclk_en <= '1' when chip_sel_cs = s4 else
           '0';


pre_adc_cs <= '0' when chip_sel_cs = s2 or chip_sel_cs = s3 or chip_sel_cs = s4 else
              '1';
-------------------------------------------

-------------------------------------------
-- sclk edge detect
-------------------------------------------


process(reset, sys_clk)
begin
    if reset = '1' then
        adc_sclk_reg_d <= '0';
        adc_sclk_reg <= '0';
    elsif rising_edge(sys_clk) then
        adc_sclk_reg_d <= adc_sclk_reg;
        adc_sclk_reg  <= clk_div_counter(2);
        
        adc_drdy_sync <= adc_drdy_n;
    end if;
end process;


-------------------------------------------
-- serial in parallel out shift register
-- for mag b
-------------------------------------------

shifter_b : process(sys_clk)
begin
    if rising_edge(sys_clk) then
        if adc_sclk_reg_d = '1' and adc_sclk_reg = '0' and sclk_en = '1' then
            sreg_b <= sreg_b(22 downto 0) & adc_data;
        end if;
    end if;
end process;
-------------------------------------------

-------------------------------------------
-- output register for latching shifted
-- data after each 24 shifts
-------------------------------------------
reg_in : process(sys_clk)
begin
    if rising_edge(sys_clk) then
        if x_data_rdy_strb  = '1' or y_data_rdy_strb = '1' or z_data_rdy_strb = '1' then
                data_b  <= sreg_b;
        end if;
	end if;
end process;
-------------------------------------------

end behavior;
