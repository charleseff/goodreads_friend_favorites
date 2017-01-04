#!/usr/bin/env ruby

require 'pry'
require 'goodreads'
require 'oauth'


class GoodReads

  KEY    = ENV['GOODREADS_KEY']
  SECRET = ENV['GOODREADS_SECRET']

  def initialize
    recreate_connections
    @user_id = @oauth_client.user_id

  end

  def run
    friends = get_friends
    puts "Found #{friends.count} friends"

    books = []
    friends.each_with_index do |f, index|
      begin
        puts "Getting books for friend #{f['id']}, ##{index+1}"
        moar_books = get_books_and_ratings_for(f['id'])
        puts "Found #{moar_books.count} books"
        books += moar_books
      rescue Goodreads::Forbidden => e
        puts "Got Goodreads::Forbidden, Goodreads may be capping requests"
        puts "Moving on..."
      end

    end

    grouped = books.group_by { |b| b[:book][:id] }.values.sort_by { |f| -f.count }
    grouped.each do |group|
      average_score = group.inject(0) { |sum, el| sum + el[:rating].to_i }.to_f / group.size
      rating_count  = group.size
      puts "#{group[0][:book][:title]} - #{group[0][:book][:title]}: #{rating_count} ratings, #{average_score} avg score"
    end


    puts
    puts "For books with 4 or more reviews:"
    grouped.select { |group| group.size >= 4 }.sort_by { |group|
      -group.inject(0) { |sum, el| sum + el[:rating].to_i }.to_f / group.size
    }.each do |group|
      average_score = group.inject(0) { |sum, el| sum + el[:rating].to_i }.to_f / group.size
      rating_count  = group.size
      puts "#{group[0][:book][:title]} - #{group[0][:book][:author]}: #{rating_count} ratings, #{average_score} avg score"
    end

    binding.pry
  end

  def recreate_connections(oauth: true)
    @client = Goodreads::Client.new(api_key: KEY, api_secret: SECRET)
    if oauth
      consumer      = OAuth::Consumer.new(KEY,
                                          SECRET,
                                          :site => 'http://www.goodreads.com')
      request_token = consumer.get_request_token
      authorize_url = request_token.authorize_url
      puts authorize_url
      `open #{authorize_url}`
      # `curl -L #{authorize_url}`
      # sleep 2
      puts "enter when done"
      gets
      access_token  = request_token.get_access_token
      @oauth_client = Goodreads.new(oauth_token: access_token)
    end
  end

  def get_friends
    ret_friends = []
    page        = 1
    loop do
      resp        = @oauth_client.send(:oauth_request, "/friend/user/#{@user_id}", page: page)
      friends     = resp['friends']
      ret_friends += friends['user']
      if friends['end'] != friends['total']
        page += 1
      else
        break
      end
    end

    ret_friends
  end

  def get_books_and_ratings_for(user_id)
    books_and_ratings = []
    page              = 1
    loop do
      resp              = @client.shelf(user_id, 'read', page: page)
      books_and_ratings += books_and_ratings_for_books(resp['books'])
      if resp['end'] != resp['total']
        page += 1
      else
        break
      end
    end

    books_and_ratings
  end

  def books_and_ratings_for_books(books)
    return books.each_with_object([]) do |book, arr|
      hash = {
        book:   { id: book['book']['id'], title: book['book']['title'], author: book['book']['authors']['author']['name'] },
        rating: book['rating']
      }
      arr << hash
    end
  end

end

if __FILE__ == $0
  GoodReads.new.run
end