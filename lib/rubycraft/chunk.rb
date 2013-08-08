# Represents a chunk data
require 'rubycraft/nbt_helper'
require 'rubycraft/byte_converter'
require 'rubycraft/block'
require 'rubycraft/section'

module RubyCraft
  # Chunks are enumerable over blocks
  class Chunk
    include Enumerable
    include ZlibHelper

    Width = 16
    Length = 16
    Height = 256

    def self.fromNbt(bytes)
      new NbtHelper.fromNbt bytes
    end

    def initialize(nbtData)
      name, @nbtBody = nbtData
      @sections = []
      level["Sections"].map do |sec|
        @sections[sec["Y"].value] = Section.new(sec)
      end
    end

    # Iterates over the blocks
    def each(&block)
      @sections.each{|sec| sec.each(&block) if not sec.nil? }
    end


    # Converts all blocks on data do another type. Gives the block and sets
    # the received name
    def block_map(&block)
      each { |b| b.name = yield b }
    end

    # Converts all blocks on data do another type. Gives the block name sets
    # the received name
    def block_type_map(&block)
      each { |b| b.name = yield b.name.to_sym }
    end

    def [](z, x, y)
      sec_y = sec_y(y)
      if sec = @sections[sec_y]
        sec[y, z, x]
      else
        nil
      end
    end

    def []=(z, x, y, value)
      sec_y = sec_y(y)
      if sec = @sections[sec_y]
        sec[y, z, x] = value
      else
        nil
      end
    end

    def export
      secs = @sections.map{|sec| sec.export if not sec.nil? }
      level["Sections"] = NBTFile::Types::List.new(NBTFile::Types::Compound, secs)
      level["HeightMap"] = exportHeightMap
      ["", @nbtBody]
    end

    def toNbt
      NbtHelper.toBytes export
    end

    protected
    def exportHeightMap
      height_map = level["HeightMap"].values.map(&:value)
      xwidth = Width
      each do |b|
        unless b.transparent
          y, z, x = b.pos
          height_map[z*xwidth + x] = [height_map[z*xwidth + x], y+1].max
        end
      end
      return NBTFile::Types::IntArray.new(height_map)
    end

    def level
      @nbtBody["Level"]
    end

    def sec_y(y)
      y / 16
    end
  end
end
