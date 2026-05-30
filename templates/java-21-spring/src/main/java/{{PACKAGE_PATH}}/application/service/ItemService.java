package {{PACKAGE_NAME}}.application.service;

import {{PACKAGE_NAME}}.application.port.in.ItemUseCase;
import {{PACKAGE_NAME}}.domain.model.Item;
import {{PACKAGE_NAME}}.domain.port.out.ItemRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.NoSuchElementException;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional
public class ItemService implements ItemUseCase {

    private final ItemRepository itemRepository;

    @Override
    public Item create(String name, String description) {
        return itemRepository.save(new Item(name, description));
    }

    @Override
    @Transactional(readOnly = true)
    public Item findById(UUID id) {
        return itemRepository.findById(id)
                .orElseThrow(() -> new NoSuchElementException("Item not found: " + id));
    }

    @Override
    @Transactional(readOnly = true)
    public List<Item> findAll() {
        return itemRepository.findAll();
    }

    @Override
    public Item update(UUID id, String name, String description) {
        Item item = findById(id);
        item.setName(name);
        item.setDescription(description);
        return itemRepository.save(item);
    }

    @Override
    public void delete(UUID id) {
        if (!itemRepository.existsById(id)) {
            throw new NoSuchElementException("Item not found: " + id);
        }
        itemRepository.deleteById(id);
    }
}
