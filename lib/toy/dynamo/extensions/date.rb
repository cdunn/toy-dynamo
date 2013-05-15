module Toy
  module Extensions
    module Date
      def to_store(value, *)
        if value.nil? || value == ''
          nil
        else
          date = value.is_a?(::Date) || value.is_a?(::Time) ? value : ::Date.parse(value.to_s)
          #::Time.utc(date.year, date.month, date.day)
          date.to_i
        end
      rescue
        nil
      end

      def from_store(value, *)
        Time.at(value.to_i).to_date if value.present?
      end
    end
  end
end
