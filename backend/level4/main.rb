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
  DISCOUNT_PERIOD_1_RATE = 0.1
  DISCOUNT_PERIOD_1_START_DAY = 2

  DISCOUNT_PERIOD_2_RATE = 0.3
  DISCOUNT_PERIOD_2_START_DAY = 5

  DISCOUNT_PERIOD_3_RATE = 0.5
  DISCOUNT_PERIOD_3_START_DAY = 11

  ROADSIDE_ASSISSTANCE_FEE_PER_DAY = 100
  COMMISSION_RATE = 0.30
  INSURANCE_PART_RATE = 0.50
  DEDUCTIBLE_REDUCTION_OPTION_COST_PER_DAY = 400

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

  def duration
    1 + (@end_date - @start_date).to_i
  end

  # day (integer) is the day number of the rental
  def discount_of_the_day(day)
    case day
    when (0..(DISCOUNT_PERIOD_1_START_DAY - 1)) then 0
    when (DISCOUNT_PERIOD_1_START_DAY..(DISCOUNT_PERIOD_2_START_DAY - 1)) then DISCOUNT_PERIOD_1_RATE
    when (DISCOUNT_PERIOD_2_START_DAY..(DISCOUNT_PERIOD_3_START_DAY - 1)) then DISCOUNT_PERIOD_2_RATE
    else DISCOUNT_PERIOD_3_RATE
    end
  end

  # day (integer) is the day number of the rental
  def price_of_the_day(day)
    (
      (1 - discount_of_the_day(day)) * car.price_per_day
    ).to_i
  end

  def price_time_component
    (1..duration).reduce(0) do |sum, day|
      sum + price_of_the_day(day)
    end
  end

  def price_distance_component
    distance * car.price_per_km
  end

  def deductible_reduction_fee
    deductible_reduction ? duration * DEDUCTIBLE_REDUCTION_OPTION_COST_PER_DAY : 0
  end

  def price
    price_time_component + price_distance_component
  end

  # half of the commision goes to the insurance
  def insurance_fee
    (COMMISSION_RATE * INSURANCE_PART_RATE * price).round
  end

  # 1 euro per day goes to the roadside assistance (amounts are in cents)
  def assistance_fee
    ROADSIDE_ASSISSTANCE_FEE_PER_DAY * duration
  end

  def drivy_fee
    (COMMISSION_RATE * price - insurance_fee - assistance_fee).round
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
