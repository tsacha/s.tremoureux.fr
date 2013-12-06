# https://gist.github.com/JanDupal/3765912
module Jekyll
  class SortedForTag < Liquid::For
    def render(context)
      category = context.registers[:page]['category']
      @collection_name = @collection_name+"."+category if not category.nil?
      if not context[@collection_name].nil?
        sorted_collection = context[@collection_name].dup
        sorted_collection.sort_by! { |i| 
          (i.date.to_i+i.to_liquid[@attributes['sort_by']].to_i)*-1 || 0
        }
      
        sorted_collection_name = "#{@collection_name}_sorted".gsub('.', '_')
        context[sorted_collection_name] = sorted_collection
        @collection_name = sorted_collection_name
      end

      
      super
    end
    
    def end_tag
      'endsorted_for'
    end
  end
end

Liquid::Template.register_tag('sorted_for', Jekyll::SortedForTag)
