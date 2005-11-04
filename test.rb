require 'lazy'

def rjust_lines( lines )
   result = nil
   result = promise {
     max_length = 0
     justified_lines = lines.map { |line|
       max_length = line.length if line.length > max_length
       promise { line.rjust( result[0] ) }
     }
     [ max_length, justified_lines ]
   }
   result[1]
end

puts rjust_lines(%w(iojwioer ijijij jijoewijrioew jiew iowerojewio jieii)).join("\n")

