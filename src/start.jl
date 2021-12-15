function banner(io::IO=stdout;color=true)
    c = Base.text_colors
    tx = c[:normal] # text
    d1 = c[:bold] * c[:blue]    # first dot
    d2 = c[:bold] * c[:red]     # second dot
    d3 = c[:bold] * c[:green]   # third dot
    d4 = c[:bold] * c[:magenta] # fourth dot

    if color
        print(io,
        """
          ____        _                     |  > 是非成败转头空
         / $(d1)__$(tx) \\      | |                    |  > Success or failure,
        | $(d1)|  |$(tx) | ___ | | ___  _ __   __ _   |  > right or wrong,
        | $(d1)|  |$(tx) |/ $(d2)_$(tx) \\| |/ $(d3)_$(tx) \\| '_ \\ / $(d4)_$(tx)` |  |  > all turn out vain.
        | $(d1)|__|$(tx) | $(d2)(_)$(tx) | | $(d3)(_)$(tx) | | | | $(d4)(_)$(tx) |  |
         \\____/ \\___/|_|\\___/|_| |_|\\__, |  |  The Immortals by the River
                                     __/ |  |  -- Yang Shen 
                                    |___/   |  (Translated by Xu Yuanchong) 
        """)
    else
        print(io,
        """
          ____        _                     |  > 是非成败转头空
         / __ \\      | |                    |  > Success or failure,
        | |  | | ___ | | ___  _ __   __ _   |  > right or wrong,
        | |  | |/ _ \\| |/ _ \\| '_ \\ / _` |  |  > all turn out vain.
        | |__| | (_) | | (_) | | | | (_) |  |
         \\____/ \\___/|_|\\___/|_| |_|\\__, |  |  The Immortals by the River
                                     __/ |  |  -- Yang Shen 
                                    |___/   |  (Translated by Xu Yuanchong) 
        """)
    end
end

"""
    start(config_file="Oolong.yml";kw...)
    start(config::Config)

Should only be called on driver.
"""
function start(config_file::String="Oolong.yml";kw...)
    local config
    if isfile(config_file)
        @info "Found $config_file. Loading configs..."
        config = Configurations.from_dict(Config, YAML.load_file(config_file; dicttype=Dict{String, Any});kw...)
    else
        @info "$config_file not found in current working directory. Using default configs."
        config = Config(;kw...)
    end
    start(config)
end

function start(config::Config)
    config.banner && banner(color=config.color)

    config_str_buf = IOBuffer()
    GarishPrint.pprint(config_str_buf, config; color=config.color, compact=config.compact)
    @info "$(@__MODULE__) starting with config: $(String(take!(config_str_buf)))"

end
