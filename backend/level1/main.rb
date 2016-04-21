#!/usr/bin/env ruby
require 'json'
require 'date'

# Describes the supply side of the market place
class Car
  attr_reader :id, :price_per_day, :price_per_km

  def initialize(id, price_per_day, price_per_km)
    @id = id
    @price_per_day = price_per_day
    @price_per_km = price_per_km
  end
end

# Describes the demand side of the market place
class Rental
  attr_reader :id, :start_date, :end_date, :distance, :car, :price_per_km, :price_per_day, :duration

  # car is a Car object
  # start_date and end_date are Date objects
  def initialize(id, start_date, end_date, distance, car)
    @id = id
    @start_date = start_date
    @end_date = end_date
    @distance = distance
    @car = car
  end

  def duration
    1 + (@end_date - @start_date).to_i
  end

  def price_time_component
    duration * car.price_per_day
  end

  def price_distance_component
    distance * car.price_per_km
  end

  def price
    price_time_component + price_distance_component
  end
end

# load data
input_file = File.read('data.json')
input = JSON.parse(input_file)

# parse cars in json
# and reorganize cars objects in a hash easily searchable by id
cars = {}
input['cars'].each do |car_hash|
  cars[car_hash['id']] = Car.new(
    car_hash['id'],
    car_hash['price_per_day'],
    car_hash['price_per_km']
  )
end

# parse the json into rental objects
# keeping the json structure
rentals = input['rentals'].map do |rental_hash|
  Rental.new(
    rental_hash['id'],
    Date.parse(rental_hash['start_date']),
    Date.parse(rental_hash['end_date']),
    rental_hash['distance'],
    cars[rental_hash['car_id']]
  )
end

# generate output hash
output = {
  rentals: rentals.map do |rental|
    {
      id: rental.id,
      price: rental.price
    }
  end
}

File.write('computed_output.json', JSON.pretty_generate(output) + "\n")

# it 'should produce the correct output' do
#   expected_output_file = File.read('output.json')
#   expected_hash = JSON.parse(expected_output_file)
#   actual_hash = output
#   actual_hash.should eq(expected_hash)
# end
