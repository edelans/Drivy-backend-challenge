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

  # beware, car is a Car object
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
    1 + (Date.parse(@end_date) - Date.parse(@start_date)).to_i
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

  def driver_amount
    - price - deductible_reduction_fee
  end

  def owner_amount
    price - insurance_fee - assistance_fee - drivy_fee
  end

  def insurance_amount
    insurance_fee
  end

  def assistance_amount
    assistance_fee
  end

  def drivy_amount
    drivy_fee + deductible_reduction_fee
  end

  def generate_actions_hash
    actions = []
    actions.push(Action.new('driver', driver_amount).to_h)
    actions.push(Action.new('owner', owner_amount).to_h)
    actions.push(Action.new('insurance', insurance_amount).to_h)
    actions.push(Action.new('assistance', assistance_amount).to_h)
    actions.push(Action.new('drivy', drivy_amount).to_h)
    actions
  end
end

# describes how much money must be debited/credited for each actor
# actor can be driver/owner/insurance/assistance/drivy
class Action
  attr_accessor :who, :type, :amount

  def initialize(who, amount)
    @who = who
    @amount = amount.abs
    @type = amount > 0 ? 'credit' : 'debit'
  end

  def to_h
    { who: @who, type: @type, amount: @amount }
  end
end

# describes a modification of a rental_id
# attributes open to changes are : start_date, end_date, distance
class RentalModification
  attr_accessor :id, :rental, :start_date, :end_date, :distance

  # initialize rentalModification with a dependency injection (rental)
  def initialize(id, rental, start_date = nil, end_date = nil, distance = nil)
    @id = id
    @rental = rental
    @start_date = start_date
    @end_date = end_date
    @distance = distance
  end

  def modified_rental
    # TODO: review following syntax
    @modified_rental ||= Rental.new(rental.id,
                                    start_date || rental.start_date,
                                    end_date || rental.end_date,
                                    distance || rental.distance,
                                    rental.car,
                                    rental.deductible_reduction)
  end

  def generate_actions_hash
    actions = []
    actions.push(Action.new('driver', - (modified_rental.price + modified_rental.deductible_reduction_fee) + (rental.price + rental.deductible_reduction_fee)).to_h)
    actions.push(Action.new('owner', (modified_rental.price - modified_rental.insurance_fee - modified_rental.assistance_fee - modified_rental.drivy_fee) -(rental.price - rental.insurance_fee - rental.assistance_fee - rental.drivy_fee)).to_h)
    actions.push(Action.new('insurance', modified_rental.insurance_fee - rental.insurance_fee).to_h)
    actions.push(Action.new('assistance', modified_rental.assistance_fee - rental.assistance_fee).to_h)
    actions.push(Action.new('drivy', (modified_rental.drivy_fee + modified_rental.deductible_reduction_fee) - (rental.drivy_fee + rental.deductible_reduction_fee)).to_h)
    actions
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

# parse rentals in json
# and reorganize rentals objects in a hash easily searchable by id
rentals = {}
input['rentals'].each do |rental_hash|
  rentals[rental_hash['id']] = Rental.new(
    rental_hash['id'],
    rental_hash['start_date'],
    rental_hash['end_date'],
    rental_hash['distance'],
    cars[rental_hash['car_id']],
    rental_hash['deductible_reduction']
  )
end

# parse the json into rental modifications objects
# keeping the json structure
rental_modifications = input['rental_modifications'].map do |rental_modification_hash|
  RentalModification.new(
    rental_modification_hash['id'],
    rentals[rental_modification_hash['rental_id']],
    rental_modification_hash['start_date'],
    rental_modification_hash['end_date'],
    rental_modification_hash['distance']
  )
end

# generate output hash
output = {
  rental_modifications: rental_modifications.map do |rental_modification|
    {
      id: rental_modification.id,
      rental_id: rental_modification.rental.id,
      actions: rental_modification.generate_actions_hash
    }
  end
}

File.write('computed_output.json', JSON.pretty_generate(output) + "\n")
