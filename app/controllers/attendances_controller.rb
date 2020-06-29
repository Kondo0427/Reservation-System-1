class AttendancesController < ApplicationController
  before_action :set_user, only: [:edit_one_month, :update_one_month]
  before_action :logged_in_user, only: [:update, :edit_one_month]
  before_action :admin_or_correct_user, only: [:update, :edit_one_month, :update_one_month]
  before_action :set_one_month, only: :edit_one_month
  
  UPDATE_ERROR_MSG = "勤怠登録に失敗しました。やり直してください。"
  
  def update
    @user = User.find(params[:user_id])
    @attendance = Attendance.find(params[:id])
    if @attendance.started_at.nil?
      if @attendance.update_attributes(started_at: Time.current.change(sec: 0))
        flash[:info] = "おはようございます！"
      else
        flash[:danger] = UPDATE_ERROR_MSG
      end
    elsif @attendance.finished_at.nil?
      if @attendance.update_attributes(finished_at: Time.current.change(sec: 0))
        flash[:info] = "お疲れ様でした。"
      else
        flash[:danger] = UPDATE_ERROR_MSG
      end
    end
    redirect_to @user
  end
  
  
  
  # 勤怠確認ボタン
  def confirm_one_month
    @user = User.find(params[:id])
    @first_day = params[:date].to_date.beginning_of_month
    @last_day = @first_day.end_of_month
    # ユーザーに紐付く一ヶ月分のレコードを検索し取得します。
    @attendances = @user.attendances.where(worked_on: @first_day..@last_day).order(:worked_on)
    @worked_sum = @attendances.where.not(started_at: nil).count
  end
  
  def log_index
    # @logs =
    # if params[:search].blank?
    #   Attendance.where(user_id, attendance_status)
  end
  
  # 残業申請
  def edit_overwork_request
    @user = User.find(params[:user_id])
    @attendance = @user.attendances.find(params[:id])
    @superiors = User.where(superior: true).where.not(id: @user.id)
  end
  
  def update_overwork_request
    @user = User.find(params[:user_id])
    @attendance = @user.attendances.find(params[:id])
    scheduled_end_time = @attendance.worked_on.to_s + " " + params[:attendance][:scheduled_end_time] + ":00"
    scheduled_end_time = scheduled_end_time.to_datetime
    if params[:attendance][:business_process].blank? || params[:attendance][:confirmation].blank?
      flash[:danger] = "未入力の項目があり、残業申請に失敗しました。"
    elsif (params[:attendance][:next_day] == "0") && ((@user.designated_work_end_time.hour.to_i > scheduled_end_time.hour.to_i) || 
      ((@user.designated_work_end_time.hour.to_i == scheduled_end_time.hour.to_i) && (@user.designated_work_end_time.min.to_i >= scheduled_end_time.min.to_i)))
      flash[:danger] = "終了予定時間は指定勤務終了時間より未来の時刻を入力してください。"
    else
      @attendance.overwork_request_status = "申請中"
      @attendance.update_attributes(overwork_params)
      flash[:success] = "残業を申請しました。"
    end
    redirect_to @user
  end
  
  # 残業のお知らせモーダル表示
  def edit_notice_overwork
    @user = User.find(params[:user_id])
    @notice_users = Attendance.where(overwork_request_status: "申請中", confirmation: @user.name).order(user_id: "ASC", worked_on: "ASC").group_by(&:user_id)
  end
  
  def update_notice_overwork
    @user = User.find(params[:user_id])
    ActiveRecord::Base.transaction do
      notice_overwork_params.each do |id, item|
        if item[:change] == "1" 
          attendance = Attendance.find(id)
          attendance.update_attributes!(item)
          flash[:success] = "変更を送信しました。"
        else
          flash[:danger] = "無効な入力があり変更を送信出来ないものがありました。"
        end
      end
      redirect_to @user
    rescue ActiveRecord::RecordInvalid
      flash[:danger] = "無効な入力があり変更を送信出来ませんでした。"
    end
  end
  
  # 勤怠変更申請モーダル
  def edit_notice_attendance
    @user = User.find(params[:user_id])
    @attendancece_users = Attendance.where(edit_request_status: "申請中", edit_confirmation: @user.name).order(user_id: "ASC", worked_on: "ASC").group_by(&:user_id)
  end
  
  def update_notice_attendance
  end
  
  def edit_one_month
    @superiors = User.where(superior: true).where.not(id: @user.id)
  end
  
  def update_one_month
    ActiveRecord::Base.transaction do
      attendances_params.each do |id, item|
        if !item[:edit_confirmation].blank?
          if item[:edit_started_at].blank? || item[:edit_finished_at].blank? || item[:note].blank?
            flash[:danger] = "無効な入力があり変更を送信出来ませんでした。"
            redirect_to attendances_edit_one_month_user_url(date: params[:date]) and return
          else
            attendance = @user.attendances.find(id)
            attendance.edit_request_status = "申請中"
            attendance.update_attributes!(item)
          end
        end
      end
    flash[:success] = "勤怠変更申請を更新しました。"
    redirect_to user_url(date: params[:date])
   rescue ActiveRecord::RecordInvalid
    flash[:danger] = "無効な入力データがあった為、更新をキャンセルしました。"
    redirect_to attendances_edit_one_month_user_url(date: params[:date]) and return
   end
  end
  
  private
  
    # 勤怠変更申請
    def attendances_params
      params.require(:user).permit(attendances: [:edit_started_at, :edit_finished_at, :next_day, :note, :edit_confirmation])[:attendances]
    end
    
    # 残業申請
    def overwork_params
      params.require(:attendance).permit(:scheduled_end_time, :next_day, :business_process, :confirmation)
    end
    
    # 残業申請承認
    def notice_overwork_params
      params.require(:user).permit(attendances: [:overwork_request_status, :change])[:attendances]
    end
    
    def admin_or_correct_user
      @user = User.find(params[:user_id]) if @user.blank?
      unless current_user?(@user) || current_user.admin?
        flash[:danger] = "編集権限がありません。"
        redirect_to(root_url)
      end
    end
end
