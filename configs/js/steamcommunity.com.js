/* jshint newcap: false */

/* global $J, Ajax, g_strCountryCode, g_rgWalletInfo */
/* exports OpenCurrentSelectionInMarket PopulateMarketActions */

var runInMainWindow = function (fn) {
    var script = document.createElement('script');
    script.innerHTML = "(" + fn + ")();";
    document.head.appendChild(script);
};

var improveInventory = function () {
    runInMainWindow(function () {
        var apply = function () {
            var oldShow = window.SellItemDialog.Show;
            window.SellItemDialog.Show = function () {
                oldShow.apply(this, arguments);
                $J('#market_sell_dialog_accept_ssa').attr('checked', 'checked');
                new Ajax.Request('//steamcommunity.com/market/priceoverview/', {
                    method: 'get',
                    parameters: {
                        country: g_strCountryCode,
                        currency: typeof( g_rgWalletInfo ) !== 'undefined' ? g_rgWalletInfo.wallet_currency : 1,
                        appid: this.m_item.appid,
                        market_hash_name: typeof this.m_item.market_hash_name !== 'undefined' ? this.m_item.market_hash_name : this.m_item.market_name
                    },
                    onSuccess: function (transport) {
                        if (transport.responseJSON && transport.responseJSON.success) {
                            if (transport.responseJSON.lowest_price) {
                                var price = transport.responseJSON.lowest_price.match(/\d+\.\d+/)[0];
                                $J('#market_sell_buyercurrency_input').val(price);
                            }
                            window.SellItemDialog.OnBuyerPriceInputKeyUp();
                        }
                    }
                });
            };
            var oldOnAccept = window.SellItemDialog.OnAccept;
            window.SellItemDialog.OnAccept = function () {
                oldOnAccept.apply(this, arguments);
                if (this.m_bWaitingForUserToConfirm) {
                    window.setTimeout(function () { $J('#market_sell_dialog_ok').focus(); }, 100);
                }
            };
        };

        var check = function () {
            if (window.PopulateMarketActions && window.SellItemDialog) {
                apply();
                clearInterval(id);
            }
        };

        var id = setInterval(check, 1000);
    });
};

var improveGamecards = function () {
    runInMainWindow(function () {
        var apply = function () {
            // jshint scripturl: true
//            window.OpenCardInMarket = function (item_num, item_name) {
//                window.open('//steamcommunity.com/market/listings/753/' + item_num + '-' + item_name, '_blank');
//            };
//
//            var cards = document.getElementsByClassName('badge_card_set_card');
//            for (var i = 0, card = cards[i]; i < cards.length; card = cards[++i]) {
//                var actions = document.createElement('div');
//                actions.class = 'item_market_actions';
//                var container = card.getElementsByClassName('game_card_ctn')[0];
//                var item_name = String(container.onclick).match(/GameCardArtDialogs\(\s+"([^"]+)"/)[1];
//                var item_num = String(container.onclick).match(/items\\\/(\d+)/)[1];
//                var openButton = CreateMarketActionButton('green', 'javascript:OpenCardInMarket(' + item_num + ', "' + item_name + '")', 'Open in Market');
//                actions.appendChild(openButton);
//                card.appendChild(actions);
//            }
            $J('.badge_card_to_collect_links a:contains("Search the Market")').each(function () {
                var searchButton = $J(this);
                var href = searchButton.prop('href');
                var match = href.match(/\/\/steamcommunity.com\/market\/listings\/([^\/]+)\/([^\/]+)/);
                var appid = match[1];
                var market_hash_name = decodeURI(match[2]);
                new Ajax.Request('//steamcommunity.com/market/pricehistory/', {
                        method: 'get',
                        parameters: {
                            appid: appid,
                            market_hash_name: market_hash_name
                        },
                        onSuccess: function (transport) {
                            if (transport.responseJSON && transport.responseJSON.success && transport.responseJSON.prices) {
                                var prices = transport.responseJSON.prices;
                                var formatted = transport.responseJSON.price_prefix + prices[prices.length - 1][1].toFixed(2) + transport.responseJSON.price_suffix;
                                var searchContent = searchButton.children('span');
                                searchContent.html(searchContent.text() + ' (~' + formatted + ')');
                            }
                        },
                        onFailure: function () {}
                    });
            });
        };

        var check = function () {
            if (window.CreateMarketActionButton) {
                apply();
                clearInterval(id);
            }
        };

        var id = setInterval(check, 1000);
    });
};

if (window.location.href.match(/inventory\/?(#.*)?$/)) {
    improveInventory();
}

if (window.location.href.match(/gamecards\/\d+\/?(#.*)?$/)) {
    improveGamecards();
}

// vim:et:sw=4 ts=4
