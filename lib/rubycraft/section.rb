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
      @blocks = Matrix3d.new(Width, Length, Height).fromArray(
        section["Blocks"].value.bytes.map{|byte| Block.get(byte) })
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
      @nbt_section["Blocks"] = byte_array(@blocks.map { |b| b.id })
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
  end
end
