module Fumimi::PrettyDate
  def to_pretty
    seconds = (Time.now - self).to_i

    case seconds
      when 0 then "just now"
      when 1..59 then "#{seconds}s ago" 
      when 60..3540 then "#{seconds/60}m ago"
      when 3541..82800 then "#{((seconds+99)/3600)}h ago"
      when 82801..518400 then "#{((seconds+800)/(60*60*24))}d ago"
      else "#{((seconds+180000)/(60*60*24*7))}w ago"
    end
  end
end

Time.include(Fumimi::PrettyDate)
