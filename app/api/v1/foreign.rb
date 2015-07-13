require 'amazon/ecs'

Amazon::Ecs.options = {
	:associate_tag => 'tattn-22',
	:AWS_access_key_id => Rails.application.secrets.AWS_access_key_id,
	:AWS_secret_key => Rails.application.secrets.AWS_secret_key
}

module V1
	module Foreign extend self
		def search_book title
			return unless block_given?

			# refer: http://www.ajaxtower.jp/ecs/
			res = Amazon::Ecs.item_search(title,
																		:search_index   => 'Books',
																		:response_group => 'Medium',
																		:country        => 'jp'
																	 )
			res.items.each do |item|
				element = item.get_element('ItemAttributes')

				data = {
					# :asin => item.get('ASIN'), #B00BKY0SK2
					:title => element.get_unescaped("Title"), #のんのんびより 2&lt;のんのんびより&gt; (コミックアライブ)
					# :page_url => "http://www.amazon.co.jp/dp/#{item.get('ASIN')}?tag=#{Amazon::Ecs.options[:associate_tag]}",#http://www.amazon.co.jp/dp/B00BKY0SK2?tag=tattn-22
					:isbn => element.get("ISBN"), #4040672828  ProductGroupがeBooks のときはnil
					:author => element.get_array("Author").join(", "), #あっと
					# :product_group => element.get("ProductGroup"), #eBooks
					:manufacturer => element.get("Manufacturer"), #KADOKAWA / メディアファクトリー
					# :publication_date => element.get("PublicationDate"),

					# :small_image => item.get_hash("SmallImage"),#{"URL"=>"http://ecx.images-amazon.com/images/I/51-urJOxFzL._SL75_.jpg", "Height"=>"75", "Width"=>"53"}
					# :medium_image => item.get_hash("MediumImage"),
					# :large_image => item.get_hash("LargeImage")
				}

				yield data
			end
		end
	end
end