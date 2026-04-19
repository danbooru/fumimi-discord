class Fumimi::Colors
  RED = 0xC41C19
  BLUE = 0x009BE6
  GREEN = 0x35C64A

  PURPLE = 0x6A09BF
  YELLOW = 0xEAD084

  GREY = 0x777892
  WHITE = 0xFFFFFF

  class ANSI
    GRAY = 30
    RED = 31
    GREEN = 32
    YELLOW = 33
    BLUE = 34
    PINK = 35
    CYAN = 36
    WHITE = 37

    NORMAL = 0
    BOLD = 2
    UNDERLINE = 4
  end

  def self.message_to_ansi(message:, color:, format: "normal")
    color = ANSI.const_get(color.upcase) unless color.is_a?(Integer)
    ansi_format = ANSI.const_get(format.upcase)
    ansi_string = "\u001b[#{ansi_format};#{color}m"
    ansi_string + message.to_s + "\u001b[0m"
  end
end
