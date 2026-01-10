# frozen_string_literal: true

# Auto-generated Property-Based Tests from Alloy Specification
# Module: queue

require "pbt"

# Implementation stub - replace with your actual implementation
class Queue
  def initialize
    @elements = []
  end

  def enqueue(element)
    @elements.push(element)
    self
  end

  def dequeue
    @elements.shift
  end

  def peek
    @elements.first
  end

  def empty?
    @elements.empty?
  end

  def length
    @elements.length
  end

  def ==(other)
    @elements == other.instance_variable_get(:@elements)
  end

  def dup
    q = Queue.new
    @elements.each { |e| q.enqueue(e) }
    q
  end
end

RSpec.describe "queue" do
  describe "Queue Properties" do
    it "enqueue increases size by 1" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer), Pbt.integer) do |initial, element|
          queue = Queue.new
          initial.each { |e| queue.enqueue(e) }

          original_length = queue.length
          queue.enqueue(element)

          raise "EnqueueAddsElement failed" unless queue.length == original_length + 1
        end
      end
    end

    it "dequeue decreases size by 1 (when not empty)" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer, min: 1)) do |initial|
          queue = Queue.new
          initial.each { |e| queue.enqueue(e) }

          original_length = queue.length
          queue.dequeue

          raise "DequeueRemovesElement failed" unless queue.length == original_length - 1
        end
      end
    end

    it "FIFO - First In First Out" do
      Pbt.assert do
        Pbt.property(Pbt.integer) do |element|
          queue = Queue.new
          queue.enqueue(element)
          dequeued = queue.dequeue

          raise "FIFO failed" unless dequeued == element
        end
      end
    end

    it "enqueue-dequeue identity (round trip)" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer), Pbt.integer) do |initial, element|
          queue = Queue.new
          initial.each { |e| queue.enqueue(e) }
          original_length = queue.length

          queue.enqueue(element)
          queue.dequeue

          raise "EnqueueDequeueIdentity failed" unless queue.length == original_length
        end
      end
    end
  end
end
