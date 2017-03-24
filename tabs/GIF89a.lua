----------------------------------------
-- GIF89a encoder / decoder
----------------------------------------

-- Convert string or number to its hexadecimal representation
function string.tohex(val, len)
    if type(val) == "number" then return string.format("%0"..(len or 2).."x", val) end
    return val:gsub(".", function(c) return string.format("%0"..(len or 2).."x", string.byte(c)) end)
end


-- Return hex as little endian notation
function string.tole(hex)
    return hex:gsub("(%x%x)(%x?%x?)", function(n, m) return m..n end)
end


-- Convert hex to integer
function string.toint(hex)
    return math.tointeger(hex:gsub("%x%x", function(cc) return tonumber(cc, 16) end))
end


-- Convert hex to binary
function string.tobin(hex)
    local map = {
        ["0"] = "0000",
        ["1"] = "0001",
        ["2"] = "0010",
        ["3"] = "0011",
        ["4"] = "0100",
        ["5"] = "0101",
        ["6"] = "0110",
        ["7"] = "0111",
        ["8"] = "1000",
        ["9"] = "1001",
        ["a"] = "1010",
        ["b"] = "1011",
        ["c"] = "1100",
        ["d"] = "1101",
        ["e"] = "1110",
        ["f"] = "1111"
    }
    return hex:gsub("[0-9a-f]", map)
end


function printf(t, indent)
    if not indent then indent = "" end
    local names = {}
    for n, g in pairs(t) do
        table.insert(names, n)
    end
    table.sort(names)
    for i, n in pairs(names) do
        local v = t[n]
        if type(v) == "table" then
            if v == t then -- prevent endless loop on self reference
                print(indent..tostring(n)..": <-")
            else
                print(indent..tostring(n)..":")
                printf(v, indent.."   ")
            end
        elseif type(v) == "function" then
            print(indent..tostring(n).."()")
        else
            print(indent..tostring(n)..": "..tostring(v))
        end
    end
end


function readGifImage(file)
    local raw_data = lfs.read(file)
    local hex_content = raw_data:tohex()
    local file_pointer = 12
    
    print(hex_content)
    
    local function get_bytes(len, format)
        local from = file_pointer + 1
        local to = from + 2 * len - 1
        local chunk = hex_content:sub(from, to)
        file_pointer = to
        
        if format == "hex" then return chunk end -- return bytes as raw hex values
        if format == "bin" then return chunk:tobin() end -- return packed bytes as binary
        if len > 1 then return chunk:tole():toint() end -- return multibyte integers as little endians
        return chunk:toint() -- return singlebyte integers
    end
    
    local function get_colors(len)
        local colors = {}
        
        for pos = 1, len do
            local r = get_bytes(1)
            local g = get_bytes(1)
            local b = get_bytes(1)
            colors[pos] = color(r, g, b)
        end
        
        return colors
    end
    
    -- Header
    local Signature = raw_data:sub(1, 3)
    local Version = raw_data:sub(4, 6)
    
    -- Logical Screen Descriptor
    local LogicalScreenWidth = get_bytes(2)
    local LogicalScreenHeight = get_bytes(2)
    local ScreenDescriptorPack = get_bytes(1, "bin")
    local GlobalColorTableFlag = ScreenDescriptorPack:sub(1, 1):toint()
    local ColorResolution = ScreenDescriptorPack:sub(2, 4):toint() - 1
    local GlobalColorTableSortFlag = ScreenDescriptorPack:sub(5, 5):toint()
    local SizeOfGlobalColorTable = 2^(ScreenDescriptorPack:sub(6, 8):toint() + 1)
    local BackgroundColorIndex = GlobalColorTableFlag and get_bytes(1) or 0
    local PixelAspectRatio = get_bytes(1)
    PixelAspectRatio = PixelAspectRatio > 0 and (PixelAspectRatio + 15) / 64 or 0
    
    -- Global Color Table
    local GlobalColorTable = GlobalColorTableFlag == 1 and get_colors(SizeOfGlobalColorTable) or nil
    
    -- Main Loop
    local ExtensionIntroducer
    while ExtensionIntroducer ~= "3b" do -- Trailer
        ExtensionIntroducer = get_bytes(1, "hex")
        local GraphicControlExtension
        
        if ExtensionIntroducer == "21" then -- Any Extension Block
            local ExtensionLabel = get_bytes(1, "hex")
            if ExtensionLabel == "f9" then -- Graphic Control Extension
                GraphicControlExtension = {}
                GraphicControlExtension.ExtensionIntroducer = ExtensionIntroducer
                GraphicControlExtension.ExtensionLabel = ExtensionLabel
                GraphicControlExtension.BlockSize = get_bytes(1)
                local GraphicControlPack = get_bytes(1, "bin")
                GraphicControlExtension.ReservedBits = GraphicControlPack:sub(1, 3)
                GraphicControlExtension.DisposalMethod = GraphicControlPack:sub(4, 6):toint()
                GraphicControlExtension.UserInputFlag = GraphicControlPack:sub(5, 5):toint()
                GraphicControlExtension.TransparentColorFlag = GraphicControlPack:sub(6, 6):toint()
                GraphicControlExtension.DelayTime = get_bytes(2)
                GraphicControlExtension.TransparentColorIndex = get_bytes(1)
                GraphicControlExtension.BlockTerminator = get_bytes(1) -- zero length byte
                --elseif  ExtensionLabel == "01" then -- Plain Text Extension
                --elseif ExtensionLabel == "ff" then do end -- Application Extension
                --elseif ExtensionLabel == "fe" then do end -- Comment Extension
            end
        end
        
        ExtensionIntroducer = get_bytes(1, "hex")
        if ExtensionIntroducer == "21" then
            local ExtensionLabel = get_bytes(1, "hex")
            if ExtensionLabel == "2c" then -- Image Descriptor
                
                
            end
        end
        
        
        if Application then
            parse app block
        elseif Comment then
            parse comment block
        else
            if GraphicControl then
                parse & cache graphic block
            end
            
            check next block
            
            if PlainText then
                parse text block
            elseif ImageDescriptor then
                parse descriptor block
                parse local color table
                parse lzw image data
            end
        end
        
        
        
        if ImageDescriptor then
            parse descriptor block
            parse local color table
            parse image data
        elseif PlainText then
            parse block
        end
        
        
        -- Image Descriptor
        local ImageLeftPosition = get_bytes(2)
        local ImageTopPosition = get_bytes(2)
        local ImageWidth = get_bytes(2)
        local ImageHeight = get_bytes(2)
        local ImageDescriptorPack = get_bytes(1, "bin")
        local LocalColorTableFlag = ImageDescriptorPack:sub(1, 1):toint()
        local InterlaceFlag = ImageDescriptorPack:sub(2, 2):toint()
        local LocalColorTableSortFlag = ImageDescriptorPack:sub(3, 3):toint()
        local ImageDescriptorReserved = ImageDescriptorPack:sub(4, 5):toint()
        local SizeOfLocalColorTable = 2^(ImageDescriptorPack:sub(6, 8):toint() + 1)
        
        -- Local Color Table
        local LocalColorTable = LocalColorTableFlag == 1 and get_colors(SizeOfLocalColorTable) or nil
        
        -- Image Data
        --
    end
end
