class UsersController < Devise::RegistrationsController

  skip_before_filter :authenticate_user!, :only => [:new, :create]
  
  def create
    session.delete(:user_return_to)
    super
  end

end
