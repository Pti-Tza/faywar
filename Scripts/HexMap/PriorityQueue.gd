# PriorityQueue.gd
#implementation of a priority queue optimized for pathfinding in Godot:
class_name PriorityQueue
## Min-heap implementation for efficient pathfinding

var _heap: Array = []
var _size: int = 0

func is_empty() -> bool:
    return _size == 0

func push(item: Variant, priority: float) -> void:
    _heap.append({"item": item, "priority": priority})
    _size += 1
    _bubble_up(_size - 1)

func pop() -> Variant:
    if is_empty():
        return null
    
    var root = _heap[0].item
    _size -= 1
    
    if _size > 0:
        _heap[0] = _heap[_size]
        _bubble_down(0)
    
    _heap.remove_at(_size)
    return root

func _bubble_up(index: int) -> void:
    var current = index
    while current > 0:
        var parent = (current - 1) >> 1  # Bitwise division by 2
        if _heap[current].priority < _heap[parent].priority:
            _swap(current, parent)
            current = parent
        else:
            break

func _bubble_down(index: int) -> void:
    var current = index
    while true:
        var left = (current << 1) + 1  # Bitwise multiplication by 2
        var right = left + 1
        var smallest = current
        
        if left < _size && _heap[left].priority < _heap[smallest].priority:
            smallest = left
        if right < _size && _heap[right].priority < _heap[smallest].priority:
            smallest = right
            
        if smallest != current:
            _swap(current, smallest)
            current = smallest
        else:
            break

func _swap(a: int, b: int) -> void:
    var temp = _heap[a]
    _heap[a] = _heap[b]
    _heap[b] = temp

func size() -> int:
    return _size

func clear() -> void:
    _heap.clear()
    _size = 0