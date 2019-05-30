#!/usr/bin/env julia
using ArgParse
using Colors

function extension(filename::String)
    try 
        return match(r"\.[A-Za-z0-9]+$", filename).match
    catch 
        return ""
    end
end

function floodfill!(img::Matrix{<:Color}, initnode::CartesianIndex{2}, outside::Color, replace::Color; 
        last_check=nothing, last_check_params=nothing)
    if isapprox(outside, replace; atol=0.05)
        @error "The outside color shouldn't be the same as the replace color"
        return img
    end
    isapprox(img[initnode],outside; atol=0.05) && return img
    
    # constants
    north = CartesianIndex(-1,  0)
    south = CartesianIndex( 1,  0)
    east  = CartesianIndex( 0,  1)
    west  = CartesianIndex( 0, -1)
 
    queue = [initnode]
    sizehint!(queue,200)
    c = 1
    wnode = nothing
    enode = nothing
    changed_at = Vector{CartesianIndex}()
    sizehint!(changed_at, 200)
    while !isempty(queue)
        node = pop!(queue)
        if !isapprox(img[node],outside; atol=0.05) && img[node] != replace
            wnode = node
            enode = node + east
        end
        # Move west until color of node does match outside color
        while checkbounds(Bool, img, wnode) && !isapprox(img[wnode],outside; atol=0.05) && !isapprox(img[wnode],replace; atol=0.05)
            push!(changed_at, wnode)
            img[wnode] = replace
            if checkbounds(Bool, img, wnode + north) && !isapprox(img[wnode + north],outside; atol=0.05) && !isapprox(img[wnode + north],replace; atol=0.05)
                push!(queue, wnode + north)
            end
            if checkbounds(Bool, img, wnode + south) && !isapprox(img[wnode + south],outside; atol=0.05) && !isapprox(img[wnode + south],replace; atol=0.05)
                push!(queue, wnode + south)
            end
            wnode += west
        end
        # Move east until color of node does match outside color
        while checkbounds(Bool, img, enode) && !isapprox(img[enode],outside; atol=0.05) && !isapprox(img[enode],replace; atol=0.05)
            push!(changed_at, enode)
            img[enode] = replace
            if checkbounds(Bool, img, enode + north) && !isapprox(img[enode + north],outside; atol=0.05) && !isapprox(img[enode + north],replace; atol=0.05)
                push!(queue, enode + north)
            end
            if checkbounds(Bool, img, enode + south) && !isapprox(img[enode + south],outside; atol=0.05) && !isapprox(img[enode + south],replace; atol=0.05)
                push!(queue, enode + south)
            end
            enode += east
        end
        c += 1
    end
    if last_check != nothing
        return last_check(img, changed_at, [img[x] for x in changed_at], last_check_params)
    end
    return img
end

function more_than(img, changed_at, changed_from, params)
    outside_counter = 0
    inside_counter = 0
    for yx in changed_at
        if params[:img][yx] == params[:outside_color]
            outside_counter += 1
        else 
            inside_counter += 1
        end
    end
    if inside_counter/(inside_counter+outside_counter) > params[:more_than]
        return img
    else 
        i = 1
        for yx in changed_at
            img[yx] = changed_from[i]
            i += 1
        end
        return img
    end
end

function parse_code_color(code_color_between)
    parts = split(code_color_between,",")
    color_picker = Dict{Symbol,Tuple{Float64,Float64}}()
    if length(parts) == 1
        range = parse.(Float64,split(parts[1],"-"))
        color_picker[:r] = (range[1], range[2])
        color_picker[:g] = (range[1], range[2])
        color_picker[:b] = (range[1], range[2])
        return color_picker
    elseif length(parts) == 3
        range_r = parse.(Float64,split(parts[1],"-"))
        color_picker[:r] = (range_r[1], range_r[2])
        range_g = parse.(Float64,split(parts[2],"-"))
        color_picker[:g] = (range_g[1], range_g[2])
        range_b = parse.(Float64,split(parts[3],"-"))
        color_picker[:b] = (range_b[1], range_b[2])
        return color_picker
    else
        @error "Your code color range parameter must be of the form Float64-Float64 i.e 0.2-0.5 or three of those values for r,g,b"
        @info "The default range is used now"
        color_picker[:r] = (0.2, 0.5)
        color_picker[:g] = (0.2, 0.5)
        color_picker[:b] = (0.2, 0.5)
        return color_picker
    end
end

function rand_between(bounds::Tuple{Float64,Float64})
    return bounds[1]+rand()*bounds[2]
end

function automatic_font_size(args, size_x, size_y)
    folder = args["folder"]
    ext_pattern = args["ext"]
    ignore = args["ignore"]
    start_x = args["start_x"]
    start_y = args["start_y"]
    line_margin = args["line_margin"]

    test_line = ""
    Drawing(size_x, size_y, "code.png")
    nchars = 0
    cl = 0
    for (root, dirs, files) in walkdir(folder)
        if !occursin(ignore,root)
            for file in files
                if occursin(ext_pattern,extension(file))
                    open(root*"/"*file) do file
                        for ln in eachline(file)
                            stripped = strip(ln)*" "
                            stripped = replace(stripped, r"\s+" => " ") 
                            nchars += length(stripped)
                            cl += 1
                            if cl % 10 == 0
                                test_line *= stripped
                            end
                        end
                    end
                end
            end
        end
    end
    fsize = 1
    pixel_for_chars = (size_x-2*start_x-fsize/2)*(size_y-2*start_y)
    possible_pixel_per_char = pixel_for_chars/nchars
    c_pixel_per_char = 0
    while c_pixel_per_char < possible_pixel_per_char
        fontsize(fsize)
        w_adv = textextents(test_line)[5]
        w_adv /= length(test_line)
        c_pixel_per_char = (line_margin+fsize)*w_adv
        pixel_for_chars = (size_x-2*start_x-fsize/2)*(size_y-2*start_y)
        possible_pixel_per_char = pixel_for_chars/nchars
        fsize += 0.1
    end
    fsize -= 0.2
    println("Automatic font size: ", fsize)
    finish()
    return fsize
end

function combine_text_code(center_color)
    text_img = load("text.png")
    code_img = load("code.png")

    last_check_params = Dict{Symbol,Any}()
    last_check_params[:img] = text_img
    last_check_params[:outside_color] = RGB(0,0,0)
    last_check_params[:more_than] = 0.75 # 75%

    size_y, size_x = size(text_img)

    println("Combining text and code...")
    @time begin
    for y in 1:size_y, x in 1:size_x
        if text_img[y,x] != RGB(0,0,0)
            if !isapprox(code_img[y,x],RGB(0,0,0); atol=0.05) && !isapprox(code_img[y,x],center_color; atol=0.05)
                yx = CartesianIndex(y,x)
                code_img = floodfill!(code_img, yx, RGB(0,0,0), center_color; last_check=more_than, 
                                      last_check_params=last_check_params)
            end
        end
    end
    end
    return code_img
end

function create_poster(args)
    folder = args["folder"]
    fsize = args["fsize"]
    font_size_center_text = args["center_fsize"]
    ext_pattern = args["ext"]
    ignore = args["ignore"]
    center_text = args["center_text"]
    start_x = args["start_x"]
    start_y = args["start_y"]
    height = args["height"]
    width = args["width"]
    line_margin = args["line_margin"]
    center_color = args["center_color"]
    code_color_between = args["code_color_range"]
    rand_color = parse_code_color(code_color_between)
    
    size_x = convert(Int,round(0.393701*width*args["dpi"]))
    size_y = convert(Int,round(0.393701*height*args["dpi"]))

    println("Size of the poster in pixel: ", string(size_x)*"x"*string(size_y))

    # estimate the fontsize if currently set to -1
    if fsize == -1
        fsize = automatic_font_size(args, size_x, size_y)
    end

    Drawing(size_x, size_y, "code.png")
    origin(Point(fsize,fsize))
    background("black")
    fontsize(fsize)
    last_x = start_x
    last_y = fsize+start_y
    for (root, dirs, files) in walkdir(folder)
        if !occursin(ignore,root)
            for file in files
                if occursin(ext_pattern, extension(file))
                    open(root*"/"*file) do file
                        for ln in eachline(file)
                            stripped = strip(ln)*" "
                            stripped = replace(stripped, r"\s+" => " ") 
                            size_ln = textextents(stripped)
                            xadv_ln = size_ln[5]
                            yadv_ln = size_ln[6]
                            sethue(rand_between(rand_color[:r]), 
                                   rand_between(rand_color[:g]),
                                   rand_between(rand_color[:b]))
                            if last_x+xadv_ln > size_x-start_x
                                # print it anyway but go to next line later
                                origin(Point(last_x,last_y))
                                break_after = 1
                                stripped_part = stripped[1:1]
                                size_ln_part = textextents(stripped_part)
                                while last_x+size_ln_part[5] <= size_x-start_x
                                    break_after = nextind(stripped,break_after)
                                    stripped_part = stripped[1:break_after]
                                    size_ln_part = textextents(stripped_part)
                                end
                                text(stripped[1:prevind(stripped,break_after)])
                                origin(Point(start_x,last_y+fsize+line_margin))
                                text(stripped[break_after:end])
                                last_y += fsize+line_margin
                                last_x = textextents(stripped[break_after:end])[5]
                            else
                                origin(Point(last_x,last_y))
                                text(stripped)
                                last_x += xadv_ln
                            end
                        end
                    end
                end
            end
        end
    end  
    println("last_y: ", last_y+fsize)
    if last_y+fsize > size_y
        @warn "You might wanna choose a different font size as at the moment some part of your awesome code isn't in the poster"
    end
    println("last_x: ", last_x)
    finish()
    println("Saved code")

    Drawing(size_x, size_y, "text.png")
    fontsize(font_size_center_text)
    wtext, htext = textextents(center_text)[3:4]
    xbtext, ybtext = textextents("a")[1:2]
    background("black")
    sethue(center_color)
    text(center_text, (size_x-wtext)/2, (size_y-htext)/2+htext/2-ybtext/2)
    finish()
    println("Saved text")
    
    code_img = combine_text_code(center_color)
    save("poster.png", code_img)
    println("DONE!!!")
    println()
    println("=======================================================================================================================================")
    println("Before you print your poster please make sure that everything looks as expected ;)")
    println("Take special care at the corners of the poster. If the code overflows or there is a big gap at the end try to change the font size.")
    println("If it doesn't work as expected please file an issue.") 
    println("Otherwise enjoy your poster and consider a small donation via PayPal:")
    println("https://www.paypal.com/donate/?token=lq0Of0tLY5KGhmPV_2QDngKBt1vUucXysZNzWiC2Zs5V9lEWKXth8ksnUZBqxtL5yDCLHG&country.x=GB&locale.x=GB")
    println("=======================================================================================================================================")
end

function ArgParse.parse_item(::Type{Regex}, x::AbstractString)
    return Regex(x)
end

function ArgParse.parse_item(::Type{RGB}, x::AbstractString)
    parts = parse.(Float64,split(x,","))
    return RGB(parts...)
end

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--folder", "-f"
            help = "The code folder"
            required = true
        "--fsize"
            help = "The font size for the code. Will be determined automatically if not specified"
            arg_type = Float64
            default = -1.0
        "--ext"
            help = "File extensions of the code seperate by , i.e jl,js,py"
            arg_type = Regex
            default = r"(\.jl|\.py|\.js|\.php)"
        "--ignore"
            help = "Ignore all paths of the following form. Form as in --ext"
            arg_type = Regex
            default = r"(\/\.git|test|Ideas|docs)"
        "--center_text", "-t"
            help = "The text which gets displayed in the center of your poster"
            arg_type = String
            default = "Test"
        "--center_fsize"
            help = "The font size for the center text."
            arg_type = Float64
            default = 1400.0
        "--center_color", "-c"
            help = "The color of center_text specify as r,g,b"
            arg_type = RGB
            default = RGB(1.0,0.73,0.0)
        "--code_color_range"
            help = "Range for the random color of each code line i.e 0.2-0.5 
                    for a color between RGB(0.2,0.2,0.2) and RGB(0.5,0.5,0.5) or 0.1-0.3,0.2-0.5,0-1 to specify a range for r,g and b"
            arg_type = String
            default = "0.2-0.5"
        "--width"
            help = "Width of the poster in cm"
            arg_type = Float64
            default = 70.0
        "--height"
            help = "Width of the poster in cm"
            arg_type = Float64
            default = 50.0
        "--dpi"
            help = "DPI"
            arg_type = Float64
            default = 300.0
        "--start_x"
            help = "Start value for x like a padding left and right"
            arg_type = Int64
            default = 10
        "--start_y"
            help = "Start value for y like a padding top and \"bottom\""
            arg_type = Int64
            default = 10  
        "--line_margin"
            help = "Margin between two lines"
            arg_type = Int64
            default = 5
    end

    return parse_args(s)
end

if isinteractive() == false
    args = parse_commandline()
    println("Parsed arguments")
    using Luxor
    using Images
    using FileIO
    println("Included all libraries")
    create_poster(args)
end