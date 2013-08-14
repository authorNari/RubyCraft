require 'rubycraft/matrix3d'

module RubyCraft
  class Section
    include Enumerable
    include ZlibHelper

    Width = 16
    Length = 16
    Height = 16

    def initialize(section)
      @base_y = section["Y"].value * Height
      @nbt_section = section
      @blocks = Matrix3d.new(Width, Length, Height).fromArray(blocks_from_nbt(section))
      @blocks.each_triple_index do |b, y, z, x|
        b.pos = [y + @base_y, z, x]
      end
      data = section["Data"].value.bytes.to_a
      @blocks.each_with_index do |b, index|
        v = data[index / 2]
        if index % 2 == 0
          b.data = v & 0xF
        else
          b.data = v >> 4
        end
      end
    end

    def each(&block)
      @blocks.each &block
    end

    def block_map(&block)
      each { |b| b.name = yield b }
    end

    def block_type_map(&block)
      each { |b| b.name = yield b.name.to_sym }
    end

    def [](y, z, x)
      @blocks[x, y - @base_y, z]
    end

    def []=(y, z, x, value)
      value.pos = [y, z, x]
      @blocks[x, y - @base_y, z] = value
    end

    def export
      @nbt_section["Data"] = byte_array(export_level_data)
      block_ids = @blocks.map(&:id)
      @nbt_section["Blocks"] = byte_array(block_ids)
      if block_ids.any?{|id| id > 255}
        adds = block_ids.map.with_index do |_,i|
          (i % 2 == 0) ? [block_ids[i], block_ids[i+1]] : nil
        end.compact.map do |b1, b2|
          ((b2 >> 8) << 4) + (b1 >> 8)
        end
        @nbt_section["Add"] = byte_array(adds)
      end
      return @nbt_section
    end

    private
    def export_level_data
      data = []
      @blocks.each_with_index do |b, i|
        if i % 2 == 0
          data << b.data
        else
          data[i / 2] += (b.data << 4)
        end
      end
      data
    end

    def byte_array(data)
      NBTFile::Types::ByteArray.new ByteConverter.toByteString(data)
    end

    def blocks_from_nbt(section)
      block_bytes = section["Blocks"].value.bytes
      if section["Add"]
        add_bytes = section["Add"].value.bytes.map{|b| [b & 15, b >> 4] }.flatten
        return block_bytes.zip(add_bytes).map{|b, a| Block.get((a << 8) + b) }
      else
        return block_bytes.map{|b| Block.get(b) }
      end
    end
  end
end
