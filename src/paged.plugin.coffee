# Export Plugin
module.exports = (BasePlugin) ->
	balUtil = require('bal-util')

	class PagedPlugin extends BasePlugin
		# Plugin Name
		name: 'paged'

		config:
			pageExtension: 'page'

		constructor: ->
			super
			docpad = @docpad
			config = @config

		docpadReady: (opts,next) ->
			# Prepare
			{docpad} = opts
			{DocumentModel} = docpad

			# Extend our prototype
			DocumentModel::getPagedUrl = (pageNumber) ->
				firstPage = @get('firstPageDoc')

				outExtension = firstPage.get('outExtension')
				baseName = firstPage.get('basename')

				if pageNumber == 0
					return firstPage.get('url')

				return firstPage.get('url').replace(outExtension, pageNumber + '.' + outExtension)

			DocumentModel::hasNextPage = ->
				page = @get('page')

				if page.number < page.count-1
					return true

				return false

			DocumentModel::getNextPage = ->
				page = @get('page')

				if page.number < page.count-1
					return @getPagedUrl(page.number+1)

				return '#'

			DocumentModel::hasPrevPage = ->
				page = @get('page')

				if page.number > 0
					return true

				return false

			DocumentModel::getPrevPage = ->
				page = @get('page')

				if page.number > 0
					return @getPagedUrl(page.number-1)

				return '#'

			next()

		renderBefore: (opts,next) ->
			docpad = @docpad
			config = @config

			{collection,templateData} = opts

			realDocuments = new docpad.FilesCollection()

			documents = collection

			documents.forEach (document) ->
				meta = document.getMeta()

				if (!meta.get('isPaged'))
					return

				# let the page meta specify count or use 1 by default
				numberOfPages = meta.get('pageCount') or 1
				pageSize = meta.get('pageSize') or 5
				lastDoc = pageSize * numberOfPages

				# if pagedCollection is specified then use that to determine number of pages
				if meta.get('pagedCollection')
					pagedCollectionName = meta.get('pagedCollection')
					pagedCollection = docpad.getCollection(pagedCollectionName)
					numberOfPages = Math.ceil(pagedCollection.length / pageSize)
					lastDoc = pagedCollection.length

				# create a page object for this page
				document.set(page: { count: numberOfPages, number: 0, size: pageSize, startIdx: 0, endIdx: Math.min(pageSize,lastDoc) })

				document.set(firstPageDoc: document)

				# loop over the number of pages we have and generate a clone of this document for each
				if numberOfPages > 1
					for n in [1..numberOfPages-1]
						pagedDocData = document.toJSON()

						pagedDoc = docpad.createDocument(pagedDocData)
						pagedDoc.set(page: { count: numberOfPages, number: n, size: pageSize, startIdx: n*pageSize, endIdx: Math.min((n*pageSize) + pageSize, lastDoc) })
						pagedDoc.set(firstPageDoc: document)
						realDocuments.add(pagedDoc)

			tasks = new balUtil.Group(next)

			realDocuments.forEach (document) ->

				tasks.push (complete) ->
					document.normalize({}, complete)

				tasks.push (complete) ->
					document.contextualize({}, complete)

				tasks.push (complete) ->
					page = document.get('page')

					basename = document.get('basename')
					outFilename = document.get('outFilename')

					outFilename = outFilename.replace(basename,basename+'.' + page.number)
					basename = basename + '.' + page.number

					document.set('basename',basename)
					document.set('outFilename', outFilename)

					complete()

			tasks.push (complete) ->
				docpad.generateRender({collection: realDocuments},complete)

			return tasks.async()