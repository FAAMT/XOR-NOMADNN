library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_MISC.all;
use IEEE.NUMERIC_STD.all;

library work;
use work.dnn_pkg.all;

entity network is
    generic (
        NUM_IN      : integer := NUM_IN; 
        NUM_HIDDEN  : integer := NUM_HIDDEN; 
        NUM_OUT     : integer := NUM_OUT;
        BASE_ADDR   : integer := BASE_ADDR 
    );
    port (
        clk           : in std_logic;
        rst           : in std_logic;

        start         : in std_logic;
        done          : out std_logic; 

        input_data    : in  network_in_array(NUM_IN-1 downto 0);
        output_data   : out ol_output_array(NUM_OUT-1 downto 0);

        result        : out  std_logic;
        target        : in   std_logic;

        weight_data   : in signed(W_WIDTH-1 downto 0);
        load_weight   : in std_logic;
        load_bias     : in std_logic;
        load_index    : in integer range 0 to NUM_IN+NUM_HIDDEN+NUM_OUT
    );
end entity network;

architecture behavioral of network is
    -- Type Declarations
    type state_type is (idle, forward_pass_1, forward_pass_2, backward_pass, weight_update, inference);
    signal state    : state_type;

    signal input_data_i         : input_array(NUM_IN-1 downto 0);

    signal gradient_load : std_logic := '0';
    signal internal_load : std_logic := '0';
    signal internal_index : integer := 0;
    signal count : integer := 0;
    signal mod_index : integer := 0;
    signal internal_weight : signed(W_WIDTH-1 downto 0);
    signal weight_data_i   : signed(W_WIDTH-1 downto 0);

    -- Hidden Layer & Output Layer
    constant HIDDEN_WIDTH : integer := 8;
    signal hidden_start         : std_logic;
    signal hidden_layer_inputs  : signed(NUM_IN*HIDDEN_WIDTH-1 downto 0);
    signal hidden_layer_outputs : output_array(NUM_HIDDEN-1 downto 0);
    signal hidden_layer_done    : std_logic_vector(NUM_HIDDEN-1 downto 0);

    constant OUTPUT_WIDTH : integer := 16;
    signal output_layer_inputs  : signed(NUM_HIDDEN*OUTPUT_WIDTH-1 downto 0);
    signal output_layer_outputs : ol_output_array(NUM_OUT-1 downto 0);
    signal output_layer_done    : std_logic_vector(NUM_OUT-1 downto 0);

    signal hidden_layer_load    : std_logic_vector(NUM_HIDDEN-1 downto 0);
    signal hidden_layer_bias    : std_logic_vector(NUM_HIDDEN-1 downto 0);
    signal hidden_layer_index   : integer range 0 to NUM_IN+NUM_HIDDEN+NUM_OUT;

    signal output_layer_weights : weights_array(NUM_HIDDEN downto 0);
    signal output_layer_load    : std_logic_vector(NUM_OUT-1 downto 0);
    signal output_layer_bias    : std_logic_vector(NUM_OUT-1 downto 0);
    signal output_layer_index   : integer range 0 to NUM_IN+NUM_HIDDEN+NUM_OUT;

    signal input_hidden_weights   : weights_array(NUM_IN*NUM_HIDDEN downto 0); 
    signal hidden_output_weights  : weights_array(NUM_HIDDEN*NUM_OUT downto 0);  
    signal updated_input_weights  :  updated_input_weights_array(NUM_IN*NUM_HIDDEN downto 0); 
    signal updated_hidden_weights :  updated_hidden_weights_array(NUM_HIDDEN*NUM_OUT downto 0);  
begin

     -- Input Data Conversion
     input_conv_proc: process(input_data)
        begin
            for i in NUM_IN-1 downto 0 loop
                input_data_i(i) <= to_signed(to_integer(unsigned(input_data(i))), input_data_i(i)'length);
            end loop;
    end process input_conv_proc;

     -- FSM Process
     fsm_process : process(clk, rst)
     begin
         if rst = '1' then
             state         <= idle;
         elsif rising_edge(clk) then
             case state is
                 when idle =>
                    done <= '0';
                    hidden_layer_inputs <= (others => '0');
                    output_layer_inputs <= (others => '0');
                    gradient_load <= '0';
                    internal_index      <= 0;
                    count               <= 3;

                    if start = '1' then
                        state <= forward_pass_1;
                    end if;
                
                 when forward_pass_1 =>
                    hidden_start <= '1';

                    -- Apply Hidden Layer Inputs & Weights
                    for i in NUM_IN-1 downto 0 loop
                        hidden_layer_inputs((i+1)*HIDDEN_WIDTH-1 downto (i*HIDDEN_WIDTH)) <= input_data_i(i);
                    end loop;

                    state <= forward_pass_2; -- 1st stage

                when forward_pass_2 =>
                    hidden_start <= '0';

                    -- Apply Output Layer Inputs & Weights
                    if and_reduce(hidden_layer_done) = '1' then 
                        for i in NUM_HIDDEN-1 downto 0 loop
                            output_layer_inputs((i+1)*OUTPUT_WIDTH-1 downto (i*OUTPUT_WIDTH)) <= hidden_layer_outputs(i);
                        end loop;
                    end if;

                    if and_reduce(output_layer_done) = '1' then
                        -- Assign Network Output
                        for i in NUM_OUT-1 downto 0 loop
                            output_data(i) <= output_layer_outputs(i);
                        end loop;

                        state <= backward_pass;
                        gradient_load <= '1';
                    end if;

                when backward_pass =>
                    if count = 0 then
                        internal_load  <= '1';
                        gradient_load <= '0';
                        state <= weight_update; -- 3 clks per error calc
                    else
                        count <= count-1;
                    end if;


                 when weight_update =>

                    if internal_index = 12 then
                        state <= inference;
                        internal_load  <= '0';
                    else
                        internal_index <= internal_index + 1;
                    end if;
                   
                 when inference =>
                    done  <= '1';
                    state <= idle;
             end case;
         end if;
     end process fsm_process;

    mod_index      <= internal_index mod (NUM_HIDDEN*NUM_IN) when internal_index >= 8 else
                      internal_index;
    internal_weight <= resize(updated_input_weights(mod_index), 8)  when internal_load = '1' and internal_index < 8 else 
                       resize(updated_hidden_weights(mod_index), 8) when internal_load = '1' and mod_index < NUM_HIDDEN and internal_index >= 8 else
                       (others => '0');
    weight_data_i     <= internal_weight when internal_load = '1' else weight_data;

    hidden_layer_index <= mod_index mod NUM_IN when internal_load = '1'  and internal_index < 8 else
                          NUM_IN when load_bias = '1' else
                          load_index mod NUM_IN when load_weight = '1' 
                          else 0;

    -- Hidden Layer Weight Arbitration
    hidden_layer_mux: process(load_index, load_weight, load_bias, mod_index, internal_load)
    begin
        for i in 0 to NUM_HIDDEN-1 loop
                if (load_index / NUM_IN = i and (load_weight = '1'or load_bias = '1')) then
                    hidden_layer_load(i) <= '1';
                elsif (mod_index / NUM_IN = i  and internal_index < 8 and internal_load = '1') then
                    hidden_layer_load(i) <= '1';
                else 
                    hidden_layer_load(i) <= '0';
                end if;
        end loop;
    end process hidden_layer_mux;

    input_hidden_reg: process(clk,rst)
    begin
        if rst = '1' then
            input_hidden_weights <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if (load_index / NUM_IN <= NUM_HIDDEN-1 and (load_weight = '1') and (load_bias = '0')) then
                input_hidden_weights(load_index) <= weight_data_i;
            end if;
        end if;
    end process input_hidden_reg;

    output_layer_index <= mod_index when internal_load = '1' and internal_index >= 8 else
                          NUM_HIDDEN when load_bias = '1' else
                          load_index mod NUM_HIDDEN when load_weight = '1' 
                          else 0;

    -- Output Layer Weight Arbitration
    output_layer_mux: process(load_index, load_weight, load_bias, mod_index, internal_load)
    begin
        for i in 0 to NUM_OUT-1 loop
                if ((NUM_HIDDEN*NUM_IN*(i+1)) <= load_index)  and 
                   (load_index < (NUM_HIDDEN*NUM_IN*(i+1) + NUM_HIDDEN*NUM_OUT*(i+1)) and (load_weight = '1' or load_bias = '1')) then
                    output_layer_load(i)    <= '1';
                elsif ((mod_index mod NUM_OUT*NUM_HIDDEN) = i  and internal_load = '1' and internal_index >= 8) then
                    output_layer_load(i) <= '1';
                else 
                    output_layer_load(i)    <= '0';
                end if;
        end loop;
    end process output_layer_mux;

    hidden_output_reg: process(clk,rst)
    begin
        if rst = '1' then
            hidden_output_weights <= (others => (others => '0'));
        elsif rising_edge(clk) then
            if (internal_load = '1' and or_reduce(output_layer_load) = '1') then
                hidden_output_weights(mod_index) <= internal_weight;
            elsif ((or_reduce(output_layer_load) = '1' or load_bias = '1') and 
                (NUM_HIDDEN*NUM_IN <= load_index  and load_index < NUM_HIDDEN*(NUM_IN + NUM_OUT))) then
                    hidden_output_weights(output_layer_index) <= weight_data_i;
            end if;
        end if;
    end process hidden_output_reg;

    -- Hidden Layer Instantiations
    gen_hidden_layer: for i in 0 to NUM_HIDDEN-1 generate
        hidden_neuron: entity work.neuron
            generic map (
                NUM_IN    => NUM_IN,
                WIDTH_IN  => W_WIDTH,
                WIDTH_OUT => A_WIDTH
            )
            port map (
                clk         => clk,
                rst         => rst,
                start       => hidden_start,
                input_data  => hidden_layer_inputs,
                output_data => hidden_layer_outputs(i),
                done        => hidden_layer_done(i),
                weight_data => weight_data_i,
                load_weight => hidden_layer_load(i),
                load_bias   => hidden_layer_bias(i),
                load_index  => hidden_layer_index
            );
    end generate gen_hidden_layer;

    -- Output Layer Instantiations
    gen_output_layer: for i in 0 to NUM_OUT-1 generate
        output_neuron: entity work.neuron
            generic map (
                NUM_IN    => NUM_HIDDEN,
                BASE_ADDR => BASE_ADDR + NUM_IN*i,
                WIDTH_IN  => 2*W_WIDTH,
                WIDTH_OUT => 24
            )
            port map (
                clk         => clk,
                rst         => rst,
                start       => and_reduce(hidden_layer_done),
                input_data  => output_layer_inputs,
                output_data => output_layer_outputs(i),
                done        => output_layer_done(i),
                weight_data => weight_data_i,
                load_weight => output_layer_load(i),
                load_bias   => output_layer_bias(i),
                load_index  => output_layer_index
            );
    end generate gen_output_layer;

    -- Output Data Conversion
    output_conv_proc: process(clk,rst)
    begin
        if rst = '1' then
            result <= '0';
        elsif output_data(0) > 0 then
            result <= '1';
        else
            result <= '0';
        end if;
    end process output_conv_proc;
    
    -- Gradient Descent Calc
    gradient_descent_inst: entity work.gradient_descent
    generic map (
        NUM_IN      => NUM_IN,
        NUM_HIDDEN  => NUM_HIDDEN,
        NUM_OUT     => NUM_OUT,
        LEARN_RATE  => LEARN_RATE
    )
    port map (
        clk                     => clk,
        rst                     => rst,
        load                    => gradient_load,

        hidden_layer_outputs    => hidden_layer_outputs,
        output_layer_outputs    => output_layer_outputs,

        result                  => result,
        target                  => target,
        
        input_data              => input_data_i,
        input_hidden_weights    => input_hidden_weights,
        hidden_output_weights   => hidden_output_weights,
        updated_input_weights   => updated_input_weights,
        updated_hidden_weights  => updated_hidden_weights
    );

end behavioral;