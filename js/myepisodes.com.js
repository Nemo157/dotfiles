$('#divContainer > table tr').not('[class~="header"]').each(function() {
  var row = $(this);
  var show = row.find('a.shows').text();
  var episode = row.children().eq(4).children('b').text().split(' ')[0];
  var query = (show + ' ' + episode).replace(/[\r\n]/g, '').trim().replace(/(\s)\s*/g, '+');
  var html = '<a href="http://torrentz.eu/search?f=' + query + '" target="_blank"><img src="img/icon_acquire.gif" /></a>';
  row.find('td > img[src="img/icon_acquire.gif"]').replaceWith(html);
});
