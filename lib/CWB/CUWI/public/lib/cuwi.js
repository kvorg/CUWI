$(document).ready(function() {
    $('a.ttip').cluetip({
	local: true,
	activation: 'click',
	arrows: true,
	dropShadow: true,
	sticky: true,
	mouseOutClose: true,
	closePosition: 'title',
	cursor: 'help',
	width: 650,
	closeText: '[X]',
    });
    $('a.itip').cluetip({
	local: true,
	activation: 'hover',
	arrows: true,
	dropShadow: true,
	sticky: true,
	mouseOutClose: true,
	closePosition: 'title',
	cursor: 'help',
	width: 650,
	closeText: '[X]',
    });
});