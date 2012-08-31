require_dependency 'spree/calculator'

module Spree
  class Calculator < ActiveRecord::Base
    module Usps
      class Base < Spree::Calculator::ActiveShipping::Base

        # US Posession territory hash
        US_POSSESSIONS = {'Puerto Rico' => 'PR'}

        def carrier
          carrier_details = {
            :login => Spree::ActiveShipping::Config[:usps_login],
            :test => Spree::ActiveShipping::Config[:test_mode]
          }

          ActiveMerchant::Shipping::USPS.new(carrier_details)
        end
        
        def compute(object)
          if object.is_a?(Array)
            order = object.first.order
          elsif object.is_a?(Shipment)
            order = object.order
          else
            order = object
          end
          origin= Location.new(:country => Spree::ActiveShipping::Config[:origin_country],
                               :city => Spree::ActiveShipping::Config[:origin_city],
                               :state => Spree::ActiveShipping::Config[:origin_state],
                               :zip => Spree::ActiveShipping::Config[:origin_zip])

          addr = order.ship_address
          
          # Substituting US Possession territories for USP
          faux_state = false
          country_iso = if (faux_state = US_POSSESSIONS[addr.country.name])
            'US'
          else
            addr.country.iso
          end
          
          state_abbr = if faux_state
            faux_state
          elsif addr.state
            addr.state.abbr
          else
            addr.state_name
          end
          
          destination = Location.new(:country => country_iso,
                                    :state => state_abbr,
                                    :city => addr.city,
                                    :zip => addr.zipcode)

          rates = Rails.cache.fetch(cache_key(order)) do
            rates = retrieve_rates(origin, destination, packages(order))
          end

          return nil if rates.empty?
          # rate = rates[self.class.service_name] #TODO - Remove the service_name from the USPS calculators (no longer needed)
          rate = rates[self.class.description]
          return nil unless rate
          rate = rate.to_f + (Spree::ActiveShipping::Config[:handling_fee].to_f || 0.0)

          # divide by 100 since active_shipping rates are expressed as cents
          return rate/100.0
        end
        
      end
    end
  end
end
