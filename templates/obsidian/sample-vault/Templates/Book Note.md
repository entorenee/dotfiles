---
title: "{{title}}"
authors: <%=book.authors.map(author => `"[[${author}]]"`).join(', ')%>
categories: <%=book.categories.map(category => `"[[${category}]]"`).join(', ')%>
recommendedBy: 
series: 
seriesNumber: 
rating: 
readdates:
- started: 
- finished: 
shelf: unread
publisher: {{publisher}}
publish: {{publishDate}}
pages: {{totalPage}}
isbn10: {{isbn10}}
isbn13: {{isbn13}}
cover: <%=book.coverUrl ? `https://books.google.com/books/publisher/content/images/frontcover/${[...book.coverUrl.split("&")[0].matchAll(/id.?(.*)/g)][0][1]}?fife=w600-h900&source=gbs_api` : ''%>
dateCreated: {{date}}
---

![cover|150]({{coverUrl}})

## {{title}}

### Description

{{description}}