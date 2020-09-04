require 'yaml'
word_list = File.readlines 'wordlists.txt'

class String
  def is_upper?
    self == self.upcase
  end

  def is_lower?
    self == self.downcase
  end
end

module Hangman
  SPACE = ' ' * 12
  LINES = "\n\n"

  class Dialogue
    def start_game
      puts LINES,
           SPACE + '--H-A-N-G-M-A-N--',
           SPACE + '   1.new game',
           SPACE + '   2.load game'
      mode = gets.chomp! until mode == '1' || mode == '2'
      mode == '1' ? 'new_game' : 'load_game'
    end

    def game_result(guess_avail, guess_left, guess_count, game_result, secret_word)
      case game_result
      when 'Won'
          "Congratulations!, you have guessed the secret word in #{guess_count} turns" + (LINES * 2)
      when 'Lose'
          "You lose, the secret word is '#{secret_word}'" + (LINES * 2)
      else
          "Please enter your next guess: #{guess_left} turns left\n"\
          "Type 'save' to save your game data" + LINES
      end
    end

    def start_guess(mode, sec_word, guess_left, game_status)
      if mode == 'new_game'
        LINES + "             #{'-' * sec_word.length}\n"\
        "Guess this #{sec_word.length} letter word in #{guess_left} guesses\n"\
        "Please type your first guess" + LINES
      elsif mode == 'load_game'
        LINES + "Guess the remaining secret letters with #{guess_left} turns left: #{game_status}\n"\
        'Please enter your first guess' + LINES
      end
    end

    def guess_error(guess)
      if !guess.match(/^[[:alpha:]]+$/) || guess.nil? || guess.length != 1
        "\n WRONG INPUT!: Please type 1 alphabet letter" + LINES
      elsif @used_guesses.include? guess.upcase
        "\n '#{guess}' was already given, Please type another input" + LINES
      end
    end

    def load_prompt(file_number, file)
      "File #{file_number}: #{file[1]}\n"\
      "  Guess_Available = #{file[3]}\n\n"
    end
  end

  class File < Dialogue
    def secret_word(word_list)
      sec_word = []
      word_list.each do |word|
        word = word.chomp!
        sec_word.push(word) if word.length.between?(5, 12)
      end
      sec_word.sample
    end

    def default_values(sec_word)
      secret_lines = '-' * sec_word.length
      guess_avail = sec_word.length + 3
      "#{sec_word}, #{secret_lines}, #{used_guesses = ''}, #{guess_avail}"
    end

    def save_values(sec_word, game_status, used_guesses, guess_left)
      "#{sec_word}, #{game_status}, #{used_guesses}, #{guess_left}"
    end

    def load_values(files)
      line_array = []
      puts 'Choose the number of file to load:'
      files.each_with_index do |file, index|
        file_number = index + 1
        line_array << file_number
        file = file.split(', ')
        puts load_prompt(file_number, file)
      end
      return file = gets.chomp!.to_i until line_array.include? file
    end

    def remove_file(target_file)
      file_set = []
      files = IO.readlines('saved_games.txt')
      files.each_with_index { |file, index| file_set.push(file) unless index == target_file - 1 }
      file_set
    end
  end

  class GuessResults < Dialogue
    include Hangman
    attr_accessor :valid_input, :game_status, :used_guesses

    def initialize(secret_word, game_status, used_guesses)
      @secret_word = secret_word
      @game_status = game_status
      @used_guesses = used_guesses
      @valid_input = false
    end

    def guess(guess)
      if (guess.length == 1) && (('a'..'z').include? guess.downcase) && (@used_guesses.split('').none? guess.upcase)
        @valid_input = true
        @used_guesses << guess.upcase
        display_guess(guess)
      else
        puts guess_error(guess)
      end
    end

    def display_guess(guess)
      word = @secret_word.upcase
      guess = guess.upcase
      while word.include? guess
        index = word.index(guess)
        word[index] = '*'
        @game_status[index] = @secret_word[index].is_upper? ? guess : guess.downcase
      end
      LINES + SPACE + @game_status
    end

    def current_status(guess_left)
      if @game_status == @secret_word
        'Won'
      elsif @game_status != @secret_word && guess_left == 0
        'Lose'
      else
        'In_Progress'
      end
    end
  end
end

game_script = Hangman::Dialogue.new
game_files = Hangman::File.new

game_mode = game_script.start_game

if game_mode == 'new_game'
  random_word = game_files.secret_word(word_list)
  game_values = game_files.default_values(random_word)
elsif game_mode == 'load_game'
  saved_files = File.open "saved_games.txt"
  target_file = game_files.load_values(saved_files)
  game_values = File.readlines('saved_games.txt')[target_file - 1].gsub!(/--- /, '')
  saved_files.close
end

secret_word, game_status, used_guesses, guess_available = game_values.split(', ')

guess_avail = guess_available.to_i
guess_count = (secret_word.length + 3) - guess_avail

hangman = Hangman::GuessResults.new(secret_word, game_status, used_guesses)
guess_avail.times do |guesses|
  puts game_script.start_guess(game_mode, secret_word, guess_avail, game_status) if guesses.zero?
  input = gets.chomp!

  hangman.valid_input = false
  if input == 'save'
    save_values = game_files.save_values(secret_word, hangman.game_status, hangman.used_guesses, guess_avail - guess_count)
    game_values = YAML::dump(save_values)
    if File.zero?('saved_games.txt')
      File.write('saved_games.txt', game_values)
    else
      File.write('saved_games.txt', game_values, mode: 'a')
    end
    break
  else
    guess_result = hangman.guess(input)
  end

  redo unless hangman.valid_input
  guess_count += 1
  guess_left = guess_avail - (guesses + 1)
  game_result = hangman.current_status(guess_left)

  puts guess_result,
       game_script.game_result(guess_avail, guess_left, guess_count, game_result, secret_word)

  break if game_result != 'In_Progress'
end

if game_mode == 'load_game'
  new_game_files = game_files.remove_file(target_file).each { |file| YAML::dump(file) }
  File.open('saved_games.txt', 'w').puts new_game_files
end
