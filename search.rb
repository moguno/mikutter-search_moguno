# -*- coding: utf-8 -*-

Plugin.create :search do
  @store = Gtk::ListStore.new(String)

  # コンボボックスのトレンドを再構築する
  def rebuild_trend!
    (Service.primary.twitter/:trends/:place).json(:id => 23424856).next { |result|
      @store.clear

      result[0][:trends].each { |trend|
        iter = @store.append

        @store.set_value(iter, 0, trend[:name])
      }
    }.trap { |e|
      puts e
      puts e.backtrace
    }

    Reserver.new(60 * 60) {
      rebuild_trend!
    }
  end

  rebuild_trend!

  querybox = ::Gtk::ComboBoxEntry.new(@store, 0)
  querycont = ::Gtk::VBox.new(false, 0)
  searchbtn = ::Gtk::Button.new(_('検索'))
  savebtn = ::Gtk::Button.new(_('保存'))

  querycont.
    closeup(::Gtk::HBox.new(false, 0).
            pack_start(querybox).
            closeup(searchbtn)).
    closeup(::Gtk::HBox.new(false, 0).
            closeup(savebtn))

  tab(:search, _("検索")) do
    set_icon Skin.get("search.png")
    shrink
    nativewidget querycont
    expand
    timeline :search
  end

  on_search_start do |query|
    querybox.child.text = query
    searchbtn.clicked
    timeline(:search).active! end

  querybox.child.signal_connect('activate'){ |elm|
    searchbtn.clicked }

  querybox.signal_connect('changed'){ |w|
    if w.active_iter
      searchbtn.clicked end }

  searchbtn.signal_connect('clicked'){ |elm|
    elm.sensitive = querybox.sensitive = false
    timeline(:search).clear
    Service.primary.search(q: querybox.child.text, count: 100).next{ |res|
      timeline(:search) << res if res.is_a? Array
      elm.sensitive = querybox.sensitive = true
    }.trap{ |e|
      timeline(:search) << Message.new(message: _("検索中にエラーが発生しました (%{error})" % {error: e.to_s}), system: true)
      elm.sensitive = querybox.sensitive = true } }

  savebtn.signal_connect('clicked'){ |elm|
    query = querybox.child.text
    Service.primary.search_create(query: query).next{ |saved_search|
      Plugin.call(:saved_search_register, saved_search[:id], query, Service.primary)
    }.terminate(_("検索キーワード「%{query}」を保存できませんでした。あとで試してみてください" % {query: query})) }

  Message::Entity.addlinkrule(:hashtags, /(?:#|＃)[a-zA-Z0-9_]+/, :search_hashtag){ |segment|
    Plugin.call(:search_start, '#' + segment[:url].match(/\A(?:#|＃)?(.+)\Z/)[1])
  }
end




