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
  attr_reader :id, :start_date, :end_date, :distance, :car, :deductible_reduction

  # car is a Car object
  # start_date and end_date are Date objects
  def initialize(id, start_date, end_date, distance, car, deductible_reduction)
    @id = id
    @start_date = start_date
    @end_date = end_date
    @distance = distance
    @car = car
    @deductible_reduction = deductible_reduction
  end

  # decreasing pricing for longer rentals
  # the discount is an integer
  # (0 < discount < 100)
  # it is the weighted average of all discounts accross the rental duration
  def discount
    discounts_sum = 0.0

    # price per day decreases by 10% after 1 day, over a period of 3 days max
    discounts_sum += 10.0 * [[0, duration - 1].max, 3].min

    # price per day decreases by 30% after 4 days, over a period of 6 days max
    discounts_sum += 30.0 * [[0, duration - 4].max, 6].min

    # price per day decreases by 50% after 10 days
    discounts_sum += (duration - 10) * 50 if duration > 10

    discounts_sum / duration
  end

  def duration
    1 + (@end_date - @start_date).to_i
  end

  def price_time_component
    (duration * car.price_per_day * (1 - discount / 100)).to_i
  end

  def price_distance_component
    distance * car.price_per_km
  end

  def deductible_reduction_fee
    if deductible_reduction
      duration * 400
    else
      0
    end
  end

  def price
    price_time_component + price_distance_component
  end

  # half of the commision goes to the insurance
  def insurance_fee
    (0.30 * 0.50 * price).round
  end

  # 1 euro per day goes to the roadside assistance (amounts are in cents)
  def assistance_fee
    100 * duration
  end

  def drivy_fee
    (0.30 * price - insurance_fee - assistance_fee).round
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
    cars[rental_hash['car_id']],
    rental_hash['deductible_reduction']
  )
end

# generate output hash
output = {
  rentals: rentals.map do |rental|
    {
      id: rental.id,
      price: rental.price,
      options: {
        deductible_reduction: rental.deductible_reduction_fee
      },
      commission: {
        insurance_fee: rental.insurance_fee,
        assistance_fee: rental.assistance_fee,
        drivy_fee: rental.drivy_fee
      }
    }
  end
}

File.write('computed_output.json', JSON.pretty_generate(output) + "\n")
