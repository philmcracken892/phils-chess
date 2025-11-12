let gameData = null;
let selectedSquare = null;
let validMoves = [];
const RESOURCE_NAME = 'phils-chessgame';

const pieceSymbols = {
    'white': {
        'king': '♔',
        'queen': '♕',
        'rook': '♖',
        'bishop': '♗',
        'knight': '♘',
        'pawn': '♙'
    },
    'black': {
        'king': '♚',
        'queen': '♛',
        'rook': '♜',
        'bishop': '♝',
        'knight': '♞',
        'pawn': '♟'
    }
};

// Position to index (MATCHES SERVER EXACTLY)
function positionToIndex(pos) {
    const file = pos.charCodeAt(0) - 96;
    const rank = parseInt(pos[1]);
    const index = (9 - rank) * 8 - 8 + file;
    return index;
}

// Index to position (MATCHES SERVER EXACTLY)
function indexToPosition(index) {
    const rank = 9 - Math.ceil(index / 8);
    const file = ((index - 1) % 8) + 1;
    return String.fromCharCode(96 + file) + rank;
}

window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'openChess') {
        gameData = data.gameData;
        $('#chess-container').show();
        initializeBoard();
        updateBoard(data.gameData.board);
        updateTurnDisplay();
        $('#player-color').text(capitalizeFirst(gameData.playerColor));
    } else if (data.action === 'updateBoard') {
        gameData.board = data.moveData.board;
        gameData.currentTurn = data.moveData.currentTurn;
        updateBoard(data.moveData.board);
        updateTurnDisplay();
        updateCapturedPieces(data.moveData.capturedPieces);
        clearSelection();
    } else if (data.action === 'closeChess') {
        closeChessUI();
    }
});

function closeChessUI() {
    $('#chess-container').hide();
    gameData = null;
    clearSelection();
}

function initializeBoard() {
    const board = $('#chess-board');
    board.empty();
    
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    const ranks = gameData.playerColor === 'white' ? [8,7,6,5,4,3,2,1] : [1,2,3,4,5,6,7,8];
    
    ranks.forEach(rank => {
        files.forEach(file => {
            const square = $('<div></div>');
            const position = file + rank;
            const isLight = (files.indexOf(file) + rank) % 2 === 0;
            
            square.addClass('square');
            square.addClass(isLight ? 'light' : 'dark');
            square.attr('data-position', position);
            
            if (file === 'a') {
                square.append(`<span class="rank-label">${rank}</span>`);
            }
            if (rank === (gameData.playerColor === 'white' ? 1 : 8)) {
                square.append(`<span class="file-label">${file}</span>`);
            }
            
            square.on('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                handleSquareClick(position);
            });
            
            board.append(square);
        });
    });
}

function updateBoard(boardData) {
    $('.square .piece').remove();
    
    for (let i = 1; i <= 64; i++) {
        const indexStr = i.toString();
        const piece = boardData[indexStr];
        
        if (piece && piece.type && piece.color) {
            const position = indexToPosition(i);
            const square = $(`.square[data-position="${position}"]`);
            
            if (square.length === 0) {
                continue;
            }
            
            const symbol = pieceSymbols[piece.color][piece.type];
            if (!symbol) {
                continue;
            }
            
            const pieceElement = $(`<div class="piece ${piece.color}">${symbol}</div>`);
            pieceElement.css('pointer-events', 'none');
            square.append(pieceElement);
        }
    }
}

function handleSquareClick(position) {
    if (!gameData) return;
    if (gameData.currentTurn !== gameData.playerColor) {
        return;
    }
    
    // If clicking valid move
    if (selectedSquare && validMoves.includes(position)) {
        makeMove(selectedSquare, position);
        clearSelection();
        return;
    }
    
    clearSelection();
    
    // Select piece
    const index = positionToIndex(position);
    const indexStr = index.toString();
    const piece = gameData.board[indexStr];
    
    if (piece && piece.color === gameData.playerColor) {
        selectedSquare = position;
        $(`.square[data-position="${position}"]`).addClass('selected');
        
        validMoves = getPossibleMoves(position, piece);
        validMoves.forEach(move => {
            $(`.square[data-position="${move}"]`).addClass('valid-move');
        });
    }
}

function clearSelection() {
    $('.square').removeClass('selected valid-move');
    selectedSquare = null;
    validMoves = [];
}

function getPossibleMoves(position, piece) {
    const moves = [];
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    const file = position.charCodeAt(0) - 97;
    const rank = parseInt(position[1]);
    
    switch(piece.type) {
        case 'pawn':
            const direction = piece.color === 'white' ? 1 : -1;
            if (rank + direction >= 1 && rank + direction <= 8) {
                moves.push(files[file] + (rank + direction));
                if ((piece.color === 'white' && rank === 2) || (piece.color === 'black' && rank === 7)) {
                    moves.push(files[file] + (rank + direction * 2));
                }
                if (file > 0) moves.push(files[file - 1] + (rank + direction));
                if (file < 7) moves.push(files[file + 1] + (rank + direction));
            }
            break;
            
        case 'knight':
            [[2,1], [2,-1], [-2,1], [-2,-1], [1,2], [1,-2], [-1,2], [-1,-2]].forEach(([df, dr]) => {
                const newFile = file + df;
                const newRank = rank + dr;
                if (newFile >= 0 && newFile < 8 && newRank >= 1 && newRank <= 8) {
                    moves.push(files[newFile] + newRank);
                }
            });
            break;
            
        case 'king':
            for (let df = -1; df <= 1; df++) {
                for (let dr = -1; dr <= 1; dr++) {
                    if (df === 0 && dr === 0) continue;
                    const newFile = file + df;
                    const newRank = rank + dr;
                    if (newFile >= 0 && newFile < 8 && newRank >= 1 && newRank <= 8) {
                        moves.push(files[newFile] + newRank);
                    }
                }
            }
            break;
            
        default:
            for (let r = 1; r <= 8; r++) {
                for (let f = 0; f < 8; f++) {
                    moves.push(files[f] + r);
                }
            }
    }
    
    return moves;
}

function makeMove(from, to) {
    fetch(`https://${RESOURCE_NAME}/makeMove`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({from: from, to: to})
    }).then(r => r.json()).catch(() => {});
}

function updateTurnDisplay() {
    const isPlayerTurn = gameData.currentTurn === gameData.playerColor;
    $('#turn-text').text(capitalizeFirst(gameData.currentTurn) + "'s Turn");
    $('#turn-text').css('color', isPlayerTurn ? '#4CAF50' : '#f44336');
}

function updateCapturedPieces(captured) {
    if (!captured) return;
    
    const playerCaptures = captured[gameData.playerColor] || [];
    const opponentColor = gameData.playerColor === 'white' ? 'black' : 'white';
    const opponentCaptures = captured[opponentColor] || [];
    
    $('#captured-player').empty();
    playerCaptures.forEach(piece => {
        $('#captured-player').append(`<span class="captured-piece ${piece.color}">${pieceSymbols[piece.color][piece.type]}</span>`);
    });
    
    $('#captured-opponent').empty();
    opponentCaptures.forEach(piece => {
        $('#captured-opponent').append(`<span class="captured-piece ${piece.color}">${pieceSymbols[piece.color][piece.type]}</span>`);
    });
}

function capitalizeFirst(str) {
    return str.charAt(0).toUpperCase() + str.slice(1);
}

$('#btn-forfeit').on('click', function(e) {
    e.preventDefault();
    fetch(`https://${RESOURCE_NAME}/forfeit`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({})
    }).then(r => r.json()).catch(() => {});
});

$('#btn-close').on('click', function(e) {
    e.preventDefault();
    fetch(`https://${RESOURCE_NAME}/closeGame`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({})
    }).then(r => r.json()).then(() => closeChessUI()).catch(() => {});
});

$(document).on('keyup', function(e) {
    if (e.key === 'Escape' && $('#chess-container').is(':visible')) {
        fetch(`https://${RESOURCE_NAME}/closeUI`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({})
        }).then(r => r.json()).catch(() => {});
    }
});