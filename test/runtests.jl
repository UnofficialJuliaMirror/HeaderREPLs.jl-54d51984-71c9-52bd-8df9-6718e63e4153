using HeaderREPLs, REPL
using Test

using REPL.LineEdit: transition

mutable struct CountingHeader <: AbstractHeader
    n::Int
end

function HeaderREPLs.print_header(terminal, header::CountingHeader)
    if header.n > 0
        HeaderREPLs.cmove_col(terminal, 1)
        HeaderREPLs.clear_line(terminal)
        printstyled(terminal, "Header:\n"; color=:light_magenta)
        for i = 1:header.n
            printstyled(terminal, "  ", i, '\n'; color=:light_blue)
        end
    end
end
HeaderREPLs.nlines(terminal, header::CountingHeader) = header.n == 0 ? 0 : header.n+1

function HeaderREPLs.setup_prompt(repl::HeaderREPL{CountingHeader}, hascolor::Bool)
    julia_prompt = find_prompt(repl.interface, "julia")

    prompt = REPL.LineEdit.Prompt(
        "count> ";
        prompt_prefix = hascolor ? repl.prompt_color : "",
        prompt_suffix = hascolor ?
            (repl.envcolors ? Base.input_color : repl.input_color) : "",
        complete = julia_prompt.complete,
        on_enter = REPL.return_callback)

    prompt.on_done = REPL.respond(repl, julia_prompt) do str
        Base.parse_input_line(str; filename="COUNT")
    end
    # hist will be handled automatically if repl.history_file is true
    # repl is obviously handled
    # keymap_dict is separate
    return prompt, :count
end

function HeaderREPLs.append_keymaps!(keymaps, repl::HeaderREPL{CountingHeader})
    julia_prompt = find_prompt(repl.interface, "julia")
    kms = [
        trigger_search_keymap(repl),
        mode_termination_keymap(repl, julia_prompt),
        trigger_prefix_keymap(repl),
        REPL.LineEdit.history_keymap,
        REPL.LineEdit.default_keymap,
        REPL.LineEdit.escape_defaults,
    ]
    append!(keymaps, kms)
end

increment(s, repl) = (clear_io(repl, s); repl.header.n += 1; refresh_header(repl, s))
decrement(s, repl) = (clear_io(repl, s); repl.header.n = max(0, repl.header.n-1); refresh_header(repl, s))

special_keys = Dict{Any,Any}(
    '+' => (s, repl, str) -> increment(s, repl),
    '-' => (s, repl, str) -> decrement(s, repl),
)

main_repl = Base.active_repl
repl = HeaderREPL(main_repl, CountingHeader(0))
REPL.setup_interface(repl; extra_repl_keymap=special_keys)

# Modify repl keymap so ')' enters the count> prompt
# (Normally you'd use the atreplinit mechanism)
function enter_count(s)
    prompt = find_prompt(s, "count")
    transition(s, prompt) do
        refresh_header(prompt.repl, s)
    end
end
julia_prompt = find_prompt(main_repl.interface, "julia")
julia_prompt.keymap_dict[')'] = (s, o...) -> enter_count(s)
