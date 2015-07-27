require 'foreign'
require 'securerandom'

module V1
  class Users < Grape::API

    # このクラス内で共通化出来る処理は helper に書く
    helpers do
      include V1::Helpers    # emit_empty などを使えるようにする（必須）
      def find_by_id user_id
        user = User.find_by user_id: user_id
        emit_error "指定した user_id が見つかりません", 400, 1 unless user
        user
      end

      # Strong parameter, but the following method is not secure.
      def user_params
        ActionController::Parameters.new(params).permit :user_id, :email, :password, :firstname, :lastname, :school, :lend_num, :borrow_num, :invitation_code
      end

      params :token do
        requires :token, type: String, desc: "Access token"
      end
    end

    resource :users do
      desc "Add a new user."
      params do
        requires :email, type: String, desc: "e-mail address"
        requires :password, type: String, desc: "password"
        requires :firstname, type: String, desc: "firstname of the user"
        requires :lastname, type: String, desc: "lastname of the user"
        optional :school, type: String, desc: "school of the user"
      end
      post '/', jbuilder: 'users/user' do
        if User.find_by user_id: params[:user_id]
          emit_error "すでに登録されているID", 400, 1
        else
          new_id = User.maximum(:user_id) + 1
          params[:user_id] = new_id
          params[:invitation_code] = SecureRandom.hex #TODO: 重複チェック
          @user = User.create user_params
        end
      end

      params do
        requires :user_id, type:Integer, desc: "user id"
      end
      route_param :user_id do

        desc "Get a user"
        get '/', jbuilder: 'users/user' do
          @user = find_by_id params[:user_id]
        end

        desc "Change property of a user."
        params do
          optional :email, type: String, desc: "e-mail address"
          optional :firstname, type: String, desc: "firstname of the user"
          optional :lastname, type: String, desc: "lastname of the user"
          optional :school, type: String, desc: "school of the user"
          optional :lend_num, type: Integer, desc: "The number that the user has lent a book"
          optional :borrow_num, type: Integer, desc: "The number that the user has borrowed a book"
          optional :invitation_code, type: String, desc: "invitation code"
        end
        put '/', jbuilder: 'empty' do
          user = find_by_id params[:user_id]
          user.update user_params if user
        end

        desc "Delete a user."
        delete '/', jbuilder: 'empty' do
          user = find_by_id params[:user_id]
          user.destroy if user
        end

        params do
          use :token
        end
        resource :friend do

          desc "get the friends list"
          get '/', jbuilder: 'users/users' do
            authenticate!
            friend = Friend.where(user_id: @current_user.user_id, accepted: true).map(&:friend_id)
            @users =  User.where(user_id: friend)
          end

          desc "Add a new friend."
          params do
            requires :friend_id, type: Integer, desc: "friend id"
          end
          post '/', jbuilder: 'empty' do
            authenticate!
            emit_error! "すでに登録されている友達", 400, 1 if Friend.find_by user_id: @current_user.user_id, friend_id: params[:friend_id]
            Friend.create user_id: @current_user.user_id, friend_id: params[:friend_id], accepted: false
          end

          params do
            requires :friend_id, type: Integer, desc: "friend id"
          end
          route_param :friend_id do

            desc "Delete a friend."
            delete '/', jbuilder: 'empty' do
              authenticate!
              friend = Friend.find_by user_id: @current_user.user_id, friend_id: params[:friend_id], accepted: true
              partner = Friend.find_by  user_id: @current_user.user_id,friend_id: params[:user_id], accepted: true
              emit_error! "存在しない友達", 400, 1 unless friend
              friend.destroy
              partner.destroy
            end
          end

          resource :new do

            desc "get the applicants"
            get '/', jbuilder: 'users/users' do
              authenticate!
              applicants = Friend.where(friend_id: @current_user.user_id, accepted: false).map(&:user_id)
              @users =  User.where(user_id: applicants)
            end

            params do
              requires :friend_id, type: Integer, desc: "friend id"
            end
            route_param :friend_id do

              desc "follow back"
              put '/', jbuilder: 'empty' do
                authenticate!
								if friend = Friend.find_by(user_id: params[:friend_id], friend_id: @current_user.user_id, accepted: false)
                  friend.update accepted: true
                  Friend.create user_id: @current_user.user_id, friend_id: params[:friend_id], accepted: true
                end
              end

              desc "reject friend request"
              delete '/', jbuilder: 'empty' do
                authenticate!
                req = Friend.find_by user_id: params[:friend_id], friend_id: @current_user.user_id, accepted: false
                emit_error! "存在しない友達申請", 400, 1 unless req
                req.destroy
              end

            end
          end
        end

        resource :borrow do
          get '/', jbuilder: 'borrows/borrows' do
            authenticate!
            @borrows = Borrow.where(user_id: @current_user.user_id)
          end

          params do
            requires :book_id, type: Integer, desc: "book id"
            requires :lender_id, type: Integer, desc: "lender id"
            optional :due_date, type: String, desc: "due date"
          end
          post '/', jbuilder: 'empty' do
            authenticate!

            emit_error! "すでに借りている本を借りようとしています", 400, 1 if Borrow.find_by user_id: params[:user_id], book_id: params[:book_id]#@current_user.user_id, book_id: params[:book_id]

            @borrow_book = Bookshelf.find_by user_id: params[:lender_id], book_id: params[:book_id]
            emit_error! "存在しない本を借りようとしています", 400, 1 unless @borrow_book

            if @borrow_book.borrower_id == 0
              if params[:due_date]
                Borrow.create user_id: @current_user.user_id, book_id: params[:book_id], lender_id: params[:lender_id], due_date: params[:due_date]
              else
                Borrow.create user_id: @current_user.user_id, book_id: params[:book_id], lender_id: params[:lender_id]
              end
              @borrow_book.update borrower_id: @current_user.user_id
            else
              emit_error! "すでに借りられている本を借りようとしています", 400, 1
            end
          end
        end

      end
    end
  end
end
