json.sender do
	json.partial!('users/user', user: User.find_by(user_id: req.sender_id))
end
json.book do
	json.partial!('books/book', book: Book.find_by(id: req.book_id))
end
json.accepted req.accepted
