main :: () {
  starttime := get_time();
  args := get_command_line_arguments();
  line := args[1];

  p:Position;
  if p.play(p, line) != line.count {
    log("Invalid move", p.moves+1, ":", line);
    return;
  }

  solver:Solver;
  solver.init(solver);
  score := solver.solve(solver, p);

  log("Execution time:", get_time()-starttime, "seconds.");
  log("score:", score);
  log("nodecount:", solver.nodeCount);
}




/**
 * A class storing a Connect 4 position.
 * Functions are relative to the current player to play.
 * Position containing alignment are not supported by this class.
 *
 * A binary bitboard representationis used.
 * Each column is encoded on HEIGH+1 bits.
 *
 * Example of bit order to encode for a 7x6 board
 * .  .  .  .  .  .  .
 * 5 12 19 26 33 40 47
 * 4 11 18 25 32 39 46
 * 3 10 17 24 31 38 45
 * 2  9 16 23 30 37 44
 * 1  8 15 22 29 36 43
 * 0  7 14 21 28 35 42
 *
 * Position is stored as
 * - a bitboard "mask" with 1 on any color stones
 * - a bitboard "current_player" with 1 on stones of current player
 *
 * "current_player" bitboard can be transformed into a compact and non ambiguous key
 * by adding an extra bit on top of the last non empty cell of each column.
 * This allow to identify all the empty cells whithout needing "mask" bitboard
 *
 * current_player "x" = 1, opponent "o" = 0
 * board     position  mask      key       bottom
 *           0000000   0000000   0000000   0000000
 * .......   0000000   0000000   0001000   0000000
 * ...o...   0000000   0001000   0010000   0000000
 * ..xx...   0011000   0011000   0011000   0000000
 * ..ox...   0001000   0011000   0001100   0000000
 * ..oox..   0000100   0011100   0000110   0000000
 * ..oxxo.   0001100   0011110   1101101   1111111
 *
 * current_player "o" = 1, opponent "x" = 0
 * board     position  mask      key       bottom
 *           0000000   0000000   0001000   0000000
 * ...x...   0000000   0001000   0000000   0000000
 * ...o...   0001000   0001000   0011000   0000000
 * ..xx...   0000000   0011000   0000000   0000000
 * ..ox...   0010000   0011000   0010100   0000000
 * ..oox..   0011000   0011100   0011010   0000000
 * ..oxxo.   0010010   0011110   1110011   1111111
 *
 * key is an unique representation of a board key = position + mask + bottom
 * in practice, as bottom is constant, key = position + mask is also a
 * non-ambigous representation of the position.
 */
Position :: struct {
  current_position:position_t; // bitmap of the current_player stones
  mask            :position_t; // bitmap of all the already palyed spots
  moves           :u64;        // number of moves played since the beinning of the game.

  position_t      :: u64;
  WIDTH           :: 7;
  HEIGHT          :: 6;
  MIN_SCORE       :: -(WIDTH*HEIGHT) / 2 + 3;
  MAX_SCORE       :: (WIDTH * HEIGHT + 1) / 2 - 3;

  #assert(WIDTH < 10/*, "Board's width must be less than 10"*/);
  #assert(WIDTH * (HEIGHT + 1) <= size_of(position_t)*8/*, "Board does not fit into position_t bitmask"*/);

  play :: (using p:Position, move:position_t) {
    current_position ^= mask;
    mask |= move;
    moves += 1;
  }

  play :: (using p:Position, seq:string) -> int {
    for i: 0..seq.count-1 {
      col := seq[i] - #char"1";
      if(col < 0 || col >= WIDTH || !canPlay(p, col) || isWinningMove(p, col)) return i; // invalid move
      playCol(p, col);
    }
    return seq.count;
  }


  moveScore        :: (using p:Position, move:position_t) -> u8 {return xx popcount(compute_winning_position(current_position | move, mask)); }
  canPlay          :: (using p:Position, col:int) -> bool {return (mask & top_mask_col(col)) == 0; }
  isWinningMove    :: (using p:Position, col:int) -> bool {return cast(bool) winning_position(p) & possible(p) & column_mask(col); }
  playCol          :: (using p:Position, col:int)         {play(p, (mask + bottom_mask_col(col)) & column_mask(col)); }
  winning_position :: (using p:Position) -> position_t {return compute_winning_position(current_position, mask); }
  possible         :: (using p:Position) -> position_t {return (mask + bottom_mask) & board_mask; }
  key              :: (using p:Position) -> position_t {return current_position + mask; }
  canWinNext       :: (using p:Position) -> bool       {return cast(bool) winning_position(p) & possible(p); }
  top_mask_col     :: (col:int) -> position_t {return cast(position_t) 1 << (((HEIGHT - 1) + col * (HEIGHT + 1))); }
  column_mask      :: (col:int) -> position_t {return cast(position_t) ((1 << HEIGHT) - 1) << (col * (HEIGHT + 1)); }
  bottom_mask_col  :: (col:int) -> position_t {return cast(position_t) 1 << (col * (HEIGHT + 1)); }


  opponent_winning_position :: (using p:Position) -> position_t {return compute_winning_position(current_position ^ mask, mask); }
  possibleNonLosingMoves :: (using p:Position) -> position_t {
    // assert(!canWinNext(p));
    possible_mask:position_t = possible(p);
    opponent_win:position_t = opponent_winning_position(p);
    forced_moves:position_t = possible_mask & opponent_win;
    if(forced_moves) {
      if(forced_moves & (forced_moves - 1)) // check if there is more than one forced move
        return 0;                           // the opponnent has two winning moves and you cannot stop him
      else possible_mask = forced_moves;    // enforce to play the single forced move
    }
    return possible_mask & ~(opponent_win >> 1);  // avoid to play below an opponent winning spot
  }



  make_bottom_mask :: (width:int, height:int) -> position_t {
    mask:position_t;
    for i: 1..width   mask |= cast(position_t)1 << ( (i-1) * (height+1) );
    return mask;
  }
  bottom_mask :position_t: #run make_bottom_mask(WIDTH, HEIGHT);
  board_mask  :position_t: bottom_mask * ((1 << HEIGHT) - 1);

  compute_winning_position :: (position:position_t, mask:position_t) -> position_t {
    // vertical;
    r:position_t = (position << 1) & (position << 2) & (position << 3);

    //horizontal
    p:position_t = (position << (HEIGHT + 1)) & (position << (2 * (HEIGHT + 1)));
    r |= p & (position << (3 * (HEIGHT + 1)));
    r |= p & (position >> (HEIGHT + 1));
    p = (position >> (HEIGHT + 1)) & (position >> (2 * (HEIGHT + 1)));
    r |= p & (position << (HEIGHT + 1));
    r |= p & (position >> (3 * (HEIGHT + 1)));

    //diagonal 1
    p = (position << HEIGHT) & (position << (2 * HEIGHT));
    r |= p & (position << (3 * HEIGHT));
    r |= p & (position >> HEIGHT);
    p = (position >> HEIGHT) & (position >> (2 * HEIGHT));
    r |= p & (position << HEIGHT);
    r |= p & (position >> (3 * HEIGHT));

    //diagonal 2
    p = (position << (HEIGHT + 2)) & (position << (2 * (HEIGHT + 2)));
    r |= p & (position << (3 * (HEIGHT + 2)));
    r |= p & (position >> (HEIGHT + 2));
    p = (position >> (HEIGHT + 2)) & (position >> (2 * (HEIGHT + 2)));
    r |= p & (position << (HEIGHT + 2));
    r |= p & (position >> (3 * (HEIGHT + 2)));

    return r & (board_mask ^ mask);
  }
}



Solver :: struct {
  transTable : TranspositionTable;
  nodeCount  : u64; // counter of explored nodes.

  columnOrder :[Position.WIDTH]u8: #run () -> [Position.WIDTH]u8 { // column exploration order
    columnOrder: [Position.WIDTH]u8;
    for i: 0..Position.WIDTH-1
      columnOrder[i] = cast(u8)(Position.WIDTH / 2 + (1 - 2 * (i % 2)) * (i + 1) / 2);
    return columnOrder; // example for Position.WIDTH=7: columnOrder = {3, 4, 2, 5, 1, 6, 0}
  }();

  // // column exploration order // example for Position.WIDTH=7: columnOrder = {3, 4, 2, 5, 1, 6, 0}
  // columnOrder :[Position.WIDTH]u8: #run forx i: 0..Position.WIDTH-1  cast(u8)(Position.WIDTH / 2 + (1 - 2 * (i % 2)) * (i + 1) / 2);

  init :: (using s:Solver) {
    transTable.init(transTable);
  }

  solve :: (using s:Solver, P:Position, weak:bool=false) -> int {
    if(P.canWinNext(P)) return (Position.WIDTH * Position.HEIGHT + 1 - cast(int)P.moves) / 2;
    min:int = -(Position.WIDTH * Position.HEIGHT - cast(int)P.moves) / 2;
    max:int = (Position.WIDTH * Position.HEIGHT + 1 - cast(int)P.moves) / 2;
    if(weak) {min = -1; max = 1; }

    while(min < max) {                    // iteratively narrow the min-max exploration window
      med:int = min + (max - min) / 2;
      if(med <= 0 && min / 2 < med) med = min / 2;
      else if(med >= 0 && max / 2 > med) med = max / 2;
      r:int = negamax(s, P, med, med + 1);   // use a null depth window to know if the actual score is greater or smaller than med
      if(r <= med) max = r;
      else min = r;
    }

    return min;
  }

  negamax :: (using s:Solver, P:Position, alpha:int, beta:int) -> int {
    // assert(alpha < beta);
    // assert(!P.canWinNext(P));

    if nodeCount % 1000000 == 0     log("nodecount", nodeCount);
    nodeCount += 1; // increment counter of explored nodes


    possible:Position.position_t = P.possibleNonLosingMoves(P);
    if(possible == 0)     // if no possible non losing move, opponent wins next move
      return -(Position.WIDTH * Position.HEIGHT - cast(int)P.moves) / 2;

    if(xx P.moves >= Position.WIDTH * Position.HEIGHT - 2) // check for draw game
      return 0;

    min:int = -(Position.WIDTH * Position.HEIGHT - 2 - cast(int)P.moves) / 2;  // lower bound of score as opponent cannot win next move
    if(alpha < min) {
      alpha = min;                     // there is no need to keep alpha below our max possible score.
      if(alpha >= beta) return alpha;  // prune the exploration if the [alpha;beta] window is empty.
    }

    max:int = (Position.WIDTH * Position.HEIGHT - 1 - cast(int)P.moves) / 2; // upper bound of our score as we cannot win immediately
    if(beta > max) {
      beta = max;                     // there is no need to keep beta above our max possible score.
      if(alpha >= beta) return beta;  // prune the exploration if the [alpha;beta] window is empty.
    }

    key:Position.position_t = P.key(P);
    val:int = transTable.get(transTable, key);
    if(val) {
      if(val > Position.MAX_SCORE - Position.MIN_SCORE + 1) { // we have an lower bound
        min = val + 2 * Position.MIN_SCORE - Position.MAX_SCORE - 2;
        if(alpha < min) {
          alpha = min;                     // there is no need to keep beta above our max possible score.
          if(alpha >= beta) return alpha;  // prune the exploration if the [alpha;beta] window is empty.
        }
      } else { // we have an upper bound
        max = val + Position.MIN_SCORE - 1;
        if(beta > max) {
          beta = max;                     // there is no need to keep beta above our max possible score.
          if(alpha >= beta) return beta;  // prune the exploration if the [alpha;beta] window is empty.
        }
      }
    }

    // if(int val = book.get(P)) return val + Position::MIN_SCORE - 1; // look for solutions stored in opening book

    moves:MoveSorter;
    for < i: Position.WIDTH-1..0 {
      move:Position.position_t = possible & Position.column_mask(columnOrder[i]);
      if(move) moves.add(moves, move, P.moveScore(P, move));
    }

    while(true) {
      next:Position.position_t = moves.getNext(moves);
      if(!next) break;
      P2:Position = P;
      P2.play(P2, next);  // It's opponent turn in P2 position after current player plays x column.
      score := -negamax(s, P2, -beta, -alpha); // explore opponent's score within [-beta;-alpha] windows:
      // no need to have good precision for score better than beta (opponent's score worse than -beta)
      // no need to check for score worse than alpha (opponent's score worse better than -alpha)

      if(score >= beta) {
        transTable.put(transTable, key, xx cast(int)(score + Position.MAX_SCORE - 2 * Position.MIN_SCORE + 2)); // save the lower bound of the position
        return score;  // prune the exploration if we find a possible move better than what we were looking for.
      }
      if(score > alpha) alpha = score; // reduce the [alpha;beta] window for next exploration, as we only
      // need to search for a position that is better than the best so far.
    }

    transTable.put(transTable, key, xx cast(int)(alpha - Position.MIN_SCORE + 1)); // save the upper bound of the position
    return alpha;
  }
}















MoveSorter :: struct {
  size   :u8;
  entries:[Position.WIDTH]struct {
    move :Position.position_t;
    score:u8;
  };

  add :: (using m:MoveSorter, move:Position.position_t, score:u8) {
    pos := size;
    size += 1;
    while(pos && entries[pos - 1].score > score) {
      entries[pos] = entries[pos - 1];
      pos -= 1;
    }
    entries[pos].move = move;
    entries[pos].score = score;
  }

  getNext :: (using m:MoveSorter) -> Position.position_t {
    if !size return 0;

    size -= 1;
    return entries[size].move;
  }
}




TranspositionTable :: struct {
  K            : []partial_key_t;
  V            : []value_t;

  TABLE_SIZE   :: 24; // store 2^TABLE_SIZE elements in the transpositiontbale
  size_t       :: u32;
  size         :: #run next_prime(1 << TABLE_SIZE);
  partial_key_t:: size_t;
  key_t        :: Position.position_t;
  value_t      :: u8;

  init :: (using t: TranspositionTable) {
    K = NewArray(size, partial_key_t);
    V = NewArray(size, value_t);
  }

  put :: (using t: TranspositionTable, key: key_t, value: value_t) {
    pos := index(key);
    K[pos] = cast,no_check(partial_key_t)key; // key is possibly trucated as key_t is possibly less than key_size bits.
    V[pos] = value;
  }

  get :: (using t: TranspositionTable, key: key_t) -> value_t {
    pos := index(key);
    if(K[pos] == cast,no_check(partial_key_t)key) return V[pos]; // need to cast to key_t because key may be truncated due to size of key_t
    else return 0;
  }

  index      :: (key: key_t) -> size_t {return xx (key % size); }
  med        :: (min: u64, max: u64) -> u64 { return (min + max) / 2; }
  // log2       :: (n: u32) -> u32 {return ifx n <= 1 then 0 else log2(n / 2) + 1; }
  next_prime :: (n: u64) -> u64 { return ifx has_factor(n, 2, n) then next_prime(n + 1) else n; }
  has_factor :: (n: u64, min: u64, max: u64) -> bool {
    return ifx min * min > n then false else
           ifx min + 1 >= max then n % min == 0 else
           has_factor(n, min, med(min, max)) || has_factor(n, med(min, max), max);
  }
}






#import "Basic";
log :: (args:..Any) { for args print("% ", it); print("\n"); }
