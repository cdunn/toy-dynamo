module Toy
  module Extensions
    module Time
      def to_store(value, *)
        if value.nil? || value == ''
          nil
        else
          time_class = ::Time.try(:zone).present? ? ::Time.zone : ::Time
          time = value.is_a?(::Time) ? value : time_class.parse(value.to_s)
          # strip milliseconds as Ruby does micro and bson does milli and rounding rounded wrong
          time.to_i if time
        end
      end

      def from_store(value, *)
        value = ::Time.at(value.to_i)
        if ::Time.try(:zone).present? && value.present?
          value.in_time_zone(::Time.zone)
        else
          value
        end
      end
    end
  end
end
