module PhoneticAlign

  # A morphological analysis of a word list.
  class MorphologicalAnalysis
    include Enumerable

    # WordList of words to analyze
    attr_reader :word_list
    # Discovered Morpheme objets
    attr_reader :morphemes

    # Create a morphological analysis
    #
    # [<em>word_list</em>] a WordList to analyze
    def initialize(word_list)
      @word_list = word_list
      @morphemes = []
    end

    # Display a list of hypothesized morphemes followed by a list of
    # reanalyzed words.
    def to_s
      (["Morphemes"] + ["-" * "Morphemes".length] +
       morphemes +
       ["Word List"] + ["-" * "Word List".length] +
       word_list).join("\n")
    end

    # Run the next iteration of the analysis.  This is the top-level loop of
    # the morphological analysis procedure.
    #
    # This returns nil when the analysis is complete and self when it is not.
    def next_iteration
      return nil if @word_list.all? { |word| word.fully_analyzed? }
      alignments = align_words
      allophones, meaning, morpheme_hypotheses = 
        best_morpheme_hypotheses(alignments)
      return nil if morpheme_hypotheses.empty?
      new_morpheme = Morpheme.new(allophones, meaning)
      LOGGER.debug("New morpheme: #{new_morpheme}")
      @morphemes << new_morpheme
      reanalyze_words(morpheme_hypotheses)
      self
    end

    # Generate alignments for all the word pairs in the list that have
    # overlapping semantics.
    def align_words
      alignments = []
      @word_list.each_symmetric_pair do |w1, w2|
        if (w1.meaning & w2.meaning).empty?
          LOGGER.debug("Skipping alignment for\n" +
                       "#{w1}\n#{w2}\nbecause they share no meaning")
          next
        end
        if w1.fully_analyzed? and w2.fully_analyzed?
          LOGGER.debug("Skipping alignment for fully analyzed words" +
                       "\n#{w1}\n#{w2}")
          next
        end
        alignment = Alignment.new(w1, w2)
        alignments << alignment
      end
      alignments
    end

    # Get a list of the best morpheme hypotheses in a given set of alignments.
    #
    # [_alignments_] sequence of Alignment objects
    def best_morpheme_hypotheses(alignments)
      # Get morpheme hypotheses from the alignments.
      morpheme_hypotheses = []
      alignments.each do |alignment|
        LOGGER.debug("Compare\n" +
                     "#{alignment.source_word}\n#{alignment.dest_word}")
        # TODO Incorporate substitution threshold.
        segmentation = alignment.segmentation
        segmentation.each_morpheme_hypothesis do |morpheme_hypothesis|
          LOGGER.debug("Morpheme Hypothesis\n#{morpheme_hypothesis}")
          morpheme_hypotheses << morpheme_hypothesis
        end
      end
      # Partition the morpheme hypotheses into equivalence classes based on
      # phonetic and then semantic compatibility.
      equivalence_classes =
        MorphemeHypothesisEquivalenceClasses.new(morpheme_hypotheses)
      # Return the highest-ranked set of equivalent morpheme hypotheses based
      # on the sum of the match rates of the alignments in which they appear.
      equivalence_classes.best_class do |hyps|
        hyps.inject(0) { |r, hyp| r += hyp.match_rate  }
      end
    end

    # Insert the specified morpheme hypotheses into the phonetic components of
    # their words.
    def reanalyze_words(morpheme_hypotheses)
      morpheme_hypotheses.each do |morpheme_hypothesis|
        morpheme_hypothesis.insert_into_word
      end
      LOGGER.debug("Reanalyzed word list\n#{word_list}")
    end

  end


  class MorphemeHypothesisEquivalenceClasses < Hash
    # Partition the morpheme hypotheses into phonetic and semantic equivalence
    # classes.
    #
    # [<em>morpheme_hypotheses</em>] sequence of MorphemeHypothesis objects to
    #                                partition
    def initialize(morpheme_hypotheses)
      group_into_phonetic_equivalence_classes!(morpheme_hypotheses)
      group_into_semantic_equivalence_classes!
    end

    # The morpheme hypothesese grouped by phonetic and then semantic
    # equivalence class with the allophone set displayed above the phonetic
    # class.
    def to_s
      map do |allophones, hyps|
        separator = "-"* allophones.to_s.length
        "#{allophones}\n#{separator}\n" + hyps.flatten.join("\n")
      end.join("\n\n")
    end

    # Return the best morpheme hypothesis equivalence class based on a scoring
    # function provided by the caller.
    #
    # [<em>scoring_function</em>] a block that takes a list of
    #                             MorphemeHypothesis objects and returns a
    #                             number greater than zero
    def best_class(&scoring_function)
      partition! if not @morpheme_hypotheses.nil?
      score = 0
      best_meaning = []
      best_allophones = []
      best_hypotheses = []
      each_equivalence_class do |allophones, morpheme_hypotheses|
        new_score = scoring_function.call(morpheme_hypotheses)
        LOGGER.debug("#{sprintf '%0.4f', new_score}\t" +
                     "#{allophones}:#{morpheme_hypotheses.first.meaning}")
        if new_score >= score
          score = new_score
          best_meaning = morpheme_hypotheses.first.meaning
          best_allophones = allophones
          best_hypotheses = morpheme_hypotheses
        end
      end
      [best_allophones, best_meaning, best_hypotheses]
    end

    protected

    # Enumerate over the equivalence classes created by partitioning.
    def each_equivalence_class
      each do |allophones, semantic_equivalence_classes|
        semantic_equivalence_classes.each do |morpheme_hypotheses|
          yield [allophones, morpheme_hypotheses]
        end
      end
    end

    # Create a hash of morpheme hypothesis lists indexed by compatible
    # allophone sets.
    #
    # When this function exits, the keys of this table will be allophone sets
    # and the values will be lists of corresponding morpheme hypotheses.
    def group_into_phonetic_equivalence_classes!(morpheme_hypotheses)
      morpheme_hypotheses.each do |morpheme_hypothesis|
        compatible = keys.find_all do |allophones|
          allophones.is_compatible?(morpheme_hypothesis.allophones)
        end
        case compatible.length
        when 0
          self[morpheme_hypothesis.allophones] = [morpheme_hypothesis]
        when 1
          add_hypothesis_to_phonetic_class!(compatible.first,
                                            morpheme_hypothesis)
        else
          # TODO Need a principled reason for picking one class over another
          # when multiple ones are compatible.
          add_hypothesis_to_phonetic_class!(compatible.first,
                                            morpheme_hypothesis)
        end
      end
    end

    # Add a new morpheme hypothesis to the table indexed by allophones.  If
    # the new hypothesis' allophone set is larger than the key currently in
    # the table, use it instead.
    def add_hypothesis_to_phonetic_class!(key, morpheme_hypothesis)
      new_allophones = morpheme_hypothesis.allophones
      if new_allophones.length > key.length
        self[new_allophones] = self[key]
        self.delete(key)
        key = new_allophones
      end
      self[key] << morpheme_hypothesis
    end

    # Subdivide each set of morpheme hypotheses in a phonetic equivalence
    # class into a semantic equivalence classes based on meaning
    # intersections.
    def group_into_semantic_equivalence_classes!
      each do |allophones, morpheme_hypotheses|
        self[allophones] = compile_meanings(morpheme_hypotheses)
      end
    end

    # Partition a list of morpheme hypotheses with the same phonetic component
    # into the largest intersecting meaning sets.
    #
    # Enumerate over the subsets of the list of morpheme hypotheses in order
    # from largest to smallest.  When a subset that share some meaning is
    # found, assign that intersected meaning to all the hypotheses in the
    # subset, and move those hypotheses onto a compiled morpheme hypotheses
    # list. Repeat until all hypotheses have been moved onto the compiled
    # morpheme hypotheses list.
    #
    # [<em>morpheme_hypotheses</em>] list of morpheme hypotheses with the same
    #                                phonetic component
    def compile_meanings(morpheme_hypotheses)
      compiled_morpheme_hypotheses = []
      while not morpheme_hypotheses.empty?
        # Find the largest subset of the morpheme hypotheses that share meaning.
        shared_meaning = nil
        meaning_partition = morpheme_hypotheses.powerset_by_length.find do |partition|
          shared_meaning =
          partition.inject(partition.first.meaning) do |meaning, hyp|
            meaning &= hyp.meaning
          end
          not shared_meaning.nil?
        end
        if not meaning_partition.nil?
          # Assign the shared meaning to all the morpheme hypotheses in the
          # partition and move these to the compiled morpheme hypothesis list.
          morpheme_hypotheses -= meaning_partition
          meaning_partition.map do |hyp|
            hyp.morpheme.meaning = shared_meaning
          end
          compiled_morpheme_hypotheses += [meaning_partition]
        else
          # There are no more meaning intersections.  Move all the remaining
          # hypotheses to the compiled morpheme hypothesis list.
          compiled_morpheme_hypotheses +=
            morpheme_hypotheses.map { |hyp| [hyp] }
          morpheme_hypotheses = []
        end
      end
      compiled_morpheme_hypotheses
    end

  end


end
