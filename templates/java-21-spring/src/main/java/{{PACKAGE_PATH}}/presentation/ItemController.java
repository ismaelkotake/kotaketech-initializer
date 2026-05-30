package {{PACKAGE_NAME}}.presentation;

import {{PACKAGE_NAME}}.application.port.in.ItemUseCase;
import {{PACKAGE_NAME}}.domain.model.Item;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/**
 * Inbound adapter — delegates to ItemUseCase (application layer).
 * When OpenAPI generation is active (swagger.yml present), replace this
 * with a class that implements the generated ItemApiDelegate interface.
 */
@RestController
@RequestMapping("/api/v1/items")
@RequiredArgsConstructor
public class ItemController {

    private final ItemUseCase itemUseCase;

    @PostMapping
    public ResponseEntity<Item> create(@RequestBody CreateItemRequest request) {
        Item created = itemUseCase.create(request.name(), request.description());
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }

    @GetMapping
    public ResponseEntity<List<Item>> findAll() {
        return ResponseEntity.ok(itemUseCase.findAll());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Item> findById(@PathVariable UUID id) {
        return ResponseEntity.ok(itemUseCase.findById(id));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Item> update(@PathVariable UUID id, @RequestBody CreateItemRequest request) {
        return ResponseEntity.ok(itemUseCase.update(id, request.name(), request.description()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        itemUseCase.delete(id);
        return ResponseEntity.noContent().build();
    }

    public record CreateItemRequest(String name, String description) {}
}
