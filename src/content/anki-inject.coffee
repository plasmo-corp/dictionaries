import $ from 'jquery'
import debounce from 'lodash/debounce'
import utils from "utils"

currentWordItem = null 

getAnkiInfo = (ankiSavedWord) ->
	chrome.runtime.sendMessage {
		type: 'get anki info',
		ankiSavedWord
	}, (res) ->
		if not res?.wordItem 
			currentWordItem = null 
			return 

		currentWordItem = res.wordItem

		if res.wordItem.sentence 
			$('.field#f0').append renderQuoteInfo res.wordItem 
		
		if res.lookupInfo?.images?.length 
			$('.field#f0').append renderImages res.lookupInfo.images

		if res.lookupInfo?.w
			$('.field#f0').append renderLookupDefs res.lookupInfo

			# auto open dict to look up
			utils.send 'look up', { w: res.lookupInfo.w }

		$('.field#f0').append '<br>'

		if res.lookupInfo
			$('.field#f1').append renderLookupWords res.wordItem, res.lookupInfo
			$('.field#f1').append '<br><br>'

		$('.field#f0, .field#f1').on 'input', debounce ((e) -> 
			$('img', e.target).each () ->
				$img = $(this)
				return if $img.attr('is-handling')

				$img.attr('is-handling', true)
				src = $img.attr('src')
				imageInfo = await utils.send 'image to data url', { src }
				$img.replaceWith renderImage imageInfo
		), 1000
		
	
if location.origin == 'https://ankiuser.net'
	getAnkiInfo()

$(document).on 'click', 'button.btn-primary', () ->
	return if not currentWordItem?.w

	try
		await utils.checkInTime ()->$('.field#f0').text().trim() == ''

		getAnkiInfo(currentWordItem.w)
	catch 
		console.err "Anki save failed on word: #{currentWordItem.w}"


renderQuoteInfo = (res) ->
	sanitizedSentence = utils.sanitizeHTML res.sentence
	filteredSentence = sanitizedSentence.replaceAll res.w, "<span style='font-weight: bold'>[?]</span>"
	return '''
<blockquote style="font-style:italic;font-size: 16px; padding: 0.3em 5px 0.3em 20px;border-left:5px solid #78C0A8;">
<span style="font-size: 16px;"> {sentence} </span>
<div style="margin-top: 5px;">-- <a href="{s}" style="font-size: 15px;"> {sc} </a></div>
</blockquote>
	'''.replace('{s}', res.s).replace('{sc}', res.sc).replace('{sentence}', filteredSentence)

renderImage = (image) -> 
	dataImgTpl = '''
<div style='width: 100%; 
	height: 0;
	display: inline-block;
	padding: 0;
	padding-bottom: 55%;
	background-image: url("{dataUrl}");
    background-repeat: no-repeat;
    background-position: center center;
    background-size: 100% auto;
'></div>
	'''
	return dataImgTpl.replace('{dataUrl}', image.dataUrl)

renderImages = (images) ->
	imgs = images.map((cur, i) ->
		if cur.dataUrl and i < 2  # only display two images
			return renderImage cur 
		return ''
	)
	return "<div class='fairydict-images'> #{imgs.join('')} </div>"

renderLookupDefs = (res) ->
	defTpl = (def) -> "<span class='fairydict-def' style='display: inline-flex;margin-bottom: 3px;'> #{def} </span>"
	defsTpl = (defs) -> "<span class='fairydict-defs' style='display: table-cell;padding-top: 1px;'> #{defs} </span>"
	labelsTpl = (labels) -> "<div class='fairydict-labels'> #{labels} </div>"
	labelTpl = (label) -> "<span class='fairydict-label'> #{label} </span>"
	posTpl = (pos) -> "<span class='fairydict-pos' style='display: table-cell;width: 40px;padding-top: 1px;'> #{pos} </span>"
	contentTpl = (content) -> "<div class='fairydict-content' style='font-size: 15px;line-height: 15px; padding: 0 5px; border-left:5px solid gold;'> #{content} </div>"
	pronSymbolTpl = (symbol='', type='') -> "<span class='fairydict-symbol fairydict-symbol-#{type}'> <em> #{symbol} </em> </span>"
	pronAudioTpl = (w, src='', type='', synthesis='') -> "<a class='fairydict-pron-audio fairydict-pron-audio-#{type}' href='' data-mp3='#{src}' data-synthesis='#{synthesis}' data-w='#{w}'><i class='icon-fairydict-volume'></i></a>"
	pronsTpl = (prons) -> "<div class='fairydict-prons' style='font-size: 15px;'> #{prons} </div>"

	html = ''

	if res?.prons and res.w 
		pronHtml = res.prons.reduce ((prev, cur)->
			if cur.synthesis or cur.audio
				# prev += pronSymbolTpl(cur.symbol, cur.type)
				prev += pronAudioTpl(res.w, cur.audio, cur.type, cur.synthesis)
			return prev
		), ''

	html += pronsTpl pronHtml if pronHtml
	
	labelsCon = res?.labels?.map(({ name }) -> labelTpl name if name).reduce ((prev, cur) ->
		prev += cur if cur 
		return prev
	), ''

	html += labelsTpl labelsCon if labelsCon

	renderItem = (item) ->
		posHtml = ''
		defsHtml = ''

		posHtml = posTpl item.pos if item.pos 
		defs = if Array.isArray(item.def) then item.def else [item.def]
		defsCon = defs.map((def) -> defTpl def if def).reduce (prev, next) ->
			return prev + '<br>' + next if prev and next 
			return prev 
		defsHtml = defsTpl defsCon if defsCon

		html += contentTpl posHtml + defsHtml if defsHtml

	res.defs.forEach renderItem if res?.defs
	res.defs2.forEach renderItem if res?.defs2

	return html 

renderLookupWords = (wordItem, res) ->
	wTpl = (w='', w2='') -> "<strong class='fairydict-w' style='font-size: 20px;'> #{w} </strong> &nbsp; <span style='font-size: 13px;'>#{w2}</span>"
	pronSymbolTpl = (symbol='', type='') -> "<span class='fairydict-symbol fairydict-symbol-#{type}'> <em> #{symbol} </em> </span>"
	pronAudioTpl = (w, src='', type='', synthesis='') -> "<a class='fairydict-pron-audio fairydict-pron-audio-#{type}' href='' data-mp3='#{src}' data-synthesis='#{synthesis}' data-w='#{w}'><i class='icon-fairydict-volume'></i></a>"
	pronsTpl = (w, prons) -> "<div class='fairydict-prons' style='font-size: 15px;'> #{w} #{prons} </div>"

	# show w2 if the lookup word is different from the selected word.
	w2 = if wordItem.w == res.w then '' else "[#{wordItem.w}]"
	pronHtml = ''
	wHtml = ''
	wHtml = wTpl res.w, w2

	if res?.prons and res.w 
		pronHtml = res.prons.reduce ((prev, cur)->
			if cur.synthesis or cur.audio or cur.symbol
				prev += pronSymbolTpl(cur.symbol, cur.type)
				prev += pronAudioTpl(res.w, cur.audio, cur.type, cur.synthesis) if cur.synthesis or cur.audio
			return prev
		), ''

		if res.prons.every (v)->['bre', 'ame'].includes(v.type)
			getEnglishPronAudio res.w 
			getEnglishPronSymbol res.w 
		
	return pronsTpl wHtml, pronHtml if pronHtml or wHtml

getEnglishPronSymbol = (w) ->
	{ prons } = await utils.send 'get english pron symbol', { w }

	for item in prons 
		if item.type == 'ame' and item.symbol 
			$('.field .fairydict-symbol-ame em').text(item.symbol)
		if item.type == 'bre' and item.symbol
			$('.field .fairydict-symbol-bre em').text(item.symbol)

getEnglishPronAudio = (w) ->
	{ prons } = await utils.send 'get real person voice', { w }

	for item in prons 
		if item.type == 'ame' and item.audio 
			$('.field .fairydict-pron-audio-ame').attr('data-mp3', item.audio)
		if item.type == 'bre' and item.audio
			$('.field .fairydict-pron-audio-bre').attr('data-mp3', item.audio)
