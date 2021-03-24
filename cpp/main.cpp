/*
 * This file is part of Connect4 Game Solver <http://connect4.gamesolver.org>
 * Copyright (C) 2017-2019 Pascal Pons <contact@gamesolver.org>
 *
 * Connect4 Game Solver is free software: you can redistribute it and/or
 * modify it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * Connect4 Game Solver is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with Connect4 Game Solver. If not, see <http://www.gnu.org/licenses/>.
 */

#include "Solver.hpp"
#include <iostream>

#include <thread>         // std::this_thread::sleep_for
#include <chrono>         // std::chrono::seconds
using namespace std::chrono;

using namespace GameSolver::Connect4;





/**
 * Main function.
 * Reads Connect 4 positions, line by line, from standard input
 * and writes one line per position to standard output containing:
 *  - score of the position
 *  - number of nodes explored
 *  - time spent in microsecond to solve the position.
 *
 *  Any invalid position (invalid sequence of move, or already won game)
 *  will generate an error message to standard error and an empty line to standard output.
 */
int main(/*int argc, char** argv*/) {
  Solver solver;
  // bool weak = false;
  // bool analyze = false;

  // std::string opening_book = "7x6.book";
  // for(int i = 1; i < argc; i++) {
  //   if(argv[i][0] == '-') {
  //     if(argv[i][1] == 'w') weak = true; // parameter -w: use weak solver
  //     else if(argv[i][1] == 'b') { // paramater -b: define an alternative opening book
  //       if(++i < argc) opening_book = std::string(argv[i]);
  //     }
  //     else if(argv[i][1] == 'a') { // paramater -a: make an analysis of all possible moves
  //       analyze = true;
  //     }
  //   }
  // }
  // solver.loadBook(opening_book);

  std::string line;

  // std::cout << Position::column_mask(0) << "\n";
  // std::cout << Position::bottom_mask_col(0) << "\n";
  // std::cout << Position::top_mask_col(0) << "\n";
  // std::cout << compute_winning_position(0b111111111101111111, 10) << "\n";
  // std::cout << "board mask " << Position::board_mask << "\n";
  // std::cout << "bottom mask " << Position::bottom_mask << "\n";


  for(int l = 1; std::getline(std::cin, line); l++) {
    auto start = high_resolution_clock::now();
    Position P;
    if(P.play(line) != line.size()) {
      std::cerr << "Line " << l << ": Invalid move " << (P.nbMoves() + 1) << " \"" << line << "\"" << std::endl;
    } else {
      // std::cout << "\n" << P.current_position << " " << P.mask << " " << P.moves << "\n\n";

      // std::cout << line;
      // if(analyze) {
      //   std::vector<int> scores = solver.analyze(P, weak);
      //   for(int i = 0; i < Position::WIDTH; i++) std::cout << " " << scores[i];
      // }
      // else {
        int score = solver.solve(P, false);
        auto stop = high_resolution_clock::now();
        // auto duration = duration_cast<microseconds>(stop - start);
        duration<double, std::milli> ms_double = stop - start;
        std::cout << "took this long: " << ms_double.count()/1000 << "\n";
        std::cout << "Score is: " << score << "\n";
        std::cout << "getNodeCount: " << solver.getNodeCount() << "\n";
      // }
      std::cout << std::endl;
    }
  }
}
