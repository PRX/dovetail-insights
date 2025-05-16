class RelatimeController < ApplicationController
  def to_abs
    now = Time.now.utc

    # TODO Error handling and input checking
    render plain: Relatime.rel2abs(params[:exp], params[:pos].to_sym, now)
  end
end
