class PersonMessagesController < ApplicationController

  before_filter do |controller|
    controller.ensure_logged_in t("layouts.notifications.you_must_log_in_to_send_a_message")
  end

  before_filter :fetch_recipient

  def new
    @conversation = Conversation.new
  end

  def create
    @conversation = new_conversation
    if @conversation.save
      flash[:notice] = t("layouts.notifications.message_sent")
      Delayed::Job.enqueue(MessageSentJob.new(@conversation.messages.last.id, @current_community.id))
      redirect_to @recipient
    else
      flash[:error] = t("layouts.notifications.message_not_sent")
      redirect_to root
    end
  end

  private

  def new_conversation
    conversation_params = params.require(:conversation).permit(
      message_attributes: :content
    )
    conversation_params[:message_attributes][:sender_id] = @current_user.id

    conversation = Conversation.new(conversation_params.merge(community: @current_community))
    conversation.build_starter_participation(@current_user)
    conversation.build_participation(@recipient)
    conversation
  end

  def fetch_recipient
    username = params[:person_id]
    @recipient = Person.find_by_username_and_community_id!(username, @current_community.id)
    if @current_user == @recipient
      flash[:error] = t("layouts.notifications.you_cannot_send_message_to_yourself")
      redirect_to root
    end
  end
end
