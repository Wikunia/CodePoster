using Luxor
using HttpCommon
using Images
using FileIO
using Colors

folder = "/home/ole/Julia/Juniper"
pattern = r".jl$"
ignore = r"(\/\.git|\/test|\/Ideas|\/docs)"
center_text = "Juniper.jl"
font_size_center_text = 1400
start_x = 10
start_y = 10
size_y = 5910
size_x = 8268
fsize = 27
space_code_line = 0
line_padding = 6

function floodfill!(img::Matrix{<:Color}, initnode::CartesianIndex{2}, outside::Color, replace::Color; last_check=nothing, last_check_params=nothing)
    if outside == replace
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
    c = 1
    wnode = nothing
    enode = nothing
    changed_at = Vector{CartesianIndex}()
    changed_from = Vector{RGB}()
    while !isempty(queue)
        node = pop!(queue)
        if !isapprox(img[node],outside; atol=0.05) && img[node] != replace
            wnode = node
            enode = node + east
        end
        # Move west until color of node does match outside color
        while checkbounds(Bool, img, wnode) && !isapprox(img[wnode],outside; atol=0.05) && !isapprox(img[wnode],replace; atol=0.05)
            push!(changed_at, wnode)
            push!(changed_from, img[wnode])
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
            push!(changed_from, img[enode])
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
        return last_check(img, changed_at, changed_from, last_check_params)
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

function create_poster()
    Drawing(size_x, size_y, "code.png")
    origin(Point(fsize,fsize))
    background("black")
    fontsize(fsize)
    last_x = start_x
    last_y = fsize+start_y
    for (root, dirs, files) in walkdir(folder)
        if !occursin(ignore,root)
            for file in files
                if occursin(pattern, file)
                    open(root*"/"*file) do file
                        for ln in eachline(file)
                            stripped = strip(ln)*" "
                            stripped = replace(stripped, r"\s+" => " ") 
                            size_ln = textextents(stripped)
                            xadv_ln = size_ln[5]
                            yadv_ln = size_ln[6]
                            sethue(rand(4:10)/20, rand(4:10)/20, rand(4:10)/20)
                            if last_x+space_code_line+xadv_ln > size_x-start_x
                                # print it anyway but go to next line later
                                origin(Point(last_x+space_code_line,last_y))
                                break_after = 1
                                stripped_part = stripped[1:1]
                                size_ln_part = textextents(stripped_part)
                                while last_x+size_ln_part[5] <= size_x-start_x
                                    break_after = nextind(stripped,break_after)
                                    stripped_part = stripped[1:break_after]
                                    size_ln_part = textextents(stripped_part)
                                end
                                text(stripped[1:prevind(stripped,break_after)])
                                origin(Point(start_x,last_y+fsize+line_padding))
                                text(stripped[break_after:end])
                                last_y += fsize+line_padding
                                last_x = textextents(stripped[break_after:end])[5]
                            else
                                origin(Point(last_x+space_code_line,last_y))
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
    println("last_x: ", last_x)
    finish()
    println("Saved code")

    Drawing(size_x, size_y, "text.png")
    fontsize(font_size_center_text)
    fontface("Georgia-Bold")
    wtext, htext = textextents(center_text)[3:4]
    xbtext, ybtext = textextents("a")[1:2]
    background("black")
    font_color = RGB(1.0,0.73,0.0)
    sethue(font_color)
    text(center_text, (size_x-wtext)/2, (size_y-htext)/2+font_size_center_text/2-ybtext/2)
    finish()
    println("Saved text")

    text_img = load("text.png")
    code_img = load("code.png")

    last_check_params = Dict{Symbol,Any}()
    last_check_params[:img] = text_img
    last_check_params[:outside_color] = RGB(0,0,0)
    last_check_params[:more_than] = 0.5 # 50%

    for y in 1:size_y, x in 1:size_x
        yx = CartesianIndex(y,x)
        if text_img[yx] != RGB(0,0,0)
            if !isapprox(code_img[yx],RGB(0,0,0)) && !isapprox(code_img[yx],font_color)
                code_img = floodfill!(code_img, yx, RGB(0,0,0), font_color; last_check=more_than, last_check_params=last_check_params)
            end
        end
    end
    save("poster.png", code_img)
end

@time create_poster()