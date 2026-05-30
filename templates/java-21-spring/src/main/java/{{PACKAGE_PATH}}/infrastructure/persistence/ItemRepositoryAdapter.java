package {{PACKAGE_NAME}}.infrastructure.persistence;

import {{PACKAGE_NAME}}.domain.model.Item;
import {{PACKAGE_NAME}}.domain.port.out.ItemRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Component
@RequiredArgsConstructor
public class ItemRepositoryAdapter implements ItemRepository {

    private final ItemJpaRepository jpaRepository;

    @Override
    public Item save(Item item) {
        return jpaRepository.save(item);
    }

    @Override
    public Optional<Item> findById(UUID id) {
        return jpaRepository.findById(id);
    }

    @Override
    public List<Item> findAll() {
        return jpaRepository.findAll();
    }

    @Override
    public void deleteById(UUID id) {
        jpaRepository.deleteById(id);
    }

    @Override
    public boolean existsById(UUID id) {
        return jpaRepository.existsById(id);
    }
}
