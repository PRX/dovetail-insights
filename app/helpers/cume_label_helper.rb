module CumeLabelHelper
  ##
  # +window_descriptor+ will be some number of seconds (0, 86_400, etc), which
  # is the **low end** of the range represented by that window (i.e., if
  # windows are 86_400, and the descriptor is 0, that represents [0 to 86_400]).
  #
  # Returns a good label to represent that window to the user.

  def cume_window_label(composition, window_descriptor)
    # Calculate the end of the window from the beginning (the descriptor)
    seconds = window_descriptor + composition.window

    # Show hours for the first 72 hours, then days. Use seconds if not evenly
    # divisible by days
    if seconds % 86_400 == 0 && seconds > 3 * 86_400
      days = seconds / 86_400
      "#{days.to_i} #{"day".pluralize(days)}"
    elsif seconds % 3_600 == 0
      hours = seconds / 3_600
      "#{hours.to_i} #{"hours".pluralize(hours)}"
    elsif seconds % 60 == 0
      minutes = seconds / 60
      "#{ActionController::Base.helpers.number_with_delimiter minutes.to_i} #{"minutes".pluralize(minutes)}"
    else
      "#{ActionController::Base.helpers.number_with_delimiter seconds.to_i} #{"second".pluralize(seconds)}"
    end
  end
end
