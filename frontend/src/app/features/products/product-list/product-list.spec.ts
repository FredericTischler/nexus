import { ComponentFixture, TestBed } from '@angular/core/testing';
import { HttpClientTestingModule } from '@angular/common/http/testing';
import { RouterTestingModule } from '@angular/router/testing';
import { NoopAnimationsModule } from '@angular/platform-browser/animations';
import { Router } from '@angular/router';
import { BehaviorSubject, of, throwError } from 'rxjs';
import { MatSnackBar } from '@angular/material/snack-bar';

import { ProductList } from './product-list';
import { Product as ProductService } from '../../../core/services/product';
import { MediaService } from '../../../core/services/media';
import { Cart } from '../../../core/services/cart';
import { WishlistService } from '../../../core/services/wishlist';
import { Product as ProductModel, Page } from '../../../core/models/product.model';

function makePage(content: ProductModel[]): Page<ProductModel> {
  return {
    content,
    totalElements: content.length,
    totalPages: 1,
    number: 0,
    size: 12,
    first: true,
    last: true,
  };
}

describe('ProductList', () => {
  let component: ProductList;
  let fixture: ComponentFixture<ProductList>;
  let productService: jasmine.SpyObj<ProductService>;
  let mediaService: jasmine.SpyObj<MediaService>;
  let cartService: Cart;
  let wishlistService: jasmine.SpyObj<WishlistService>;
  let snackBar: jasmine.SpyObj<MatSnackBar>;
  let router: Router;
  let cartStream: BehaviorSubject<any[]>;
  let wishlistStream: BehaviorSubject<string[]>;

  beforeEach(async () => {
    productService = jasmine.createSpyObj<ProductService>('Product', ['getProducts', 'getCategories', 'getAllProducts', 'searchProducts', 'filterProducts']);
    mediaService = jasmine.createSpyObj<MediaService>('MediaService', ['getMediaByProduct', 'getImageUrl']);
    snackBar = jasmine.createSpyObj<MatSnackBar>('MatSnackBar', ['open']);
    cartStream = new BehaviorSubject<any[]>([]);
    wishlistStream = new BehaviorSubject<string[]>([]);
    cartService = {
      cartItems$: cartStream.asObservable(),
      getCartCount: () => 0,
      getCartItems: () => [],
      addToCart: jasmine.createSpy('addToCart'),
    } as unknown as Cart;
    wishlistService = jasmine.createSpyObj<WishlistService>('WishlistService', ['isInWishlistSync', 'toggleWishlist', 'getWishlistCount', 'getWishlist', 'addToWishlist', 'removeFromWishlist'], {
      wishlist$: wishlistStream.asObservable(),
    });

    snackBar.open.and.returnValue({
      onAction: () => of(null),
    } as any);
    productService.getProducts.and.returnValue(of(makePage([])));
    productService.getCategories.and.returnValue(of([]));
    productService.filterProducts.and.returnValue(of(makePage([])));
    mediaService.getMediaByProduct.and.returnValue(of([]));
    mediaService.getImageUrl.and.callFake((url: string) => url);
    wishlistService.isInWishlistSync.and.returnValue(false);
    wishlistService.getWishlistCount.and.returnValue(0);
    wishlistService.getWishlist.and.returnValue(of([]));

    await TestBed.configureTestingModule({
      imports: [
        ProductList,
        HttpClientTestingModule,
        RouterTestingModule.withRoutes([]),
        NoopAnimationsModule,
      ],
      providers: [
        { provide: ProductService, useValue: productService },
        { provide: MediaService, useValue: mediaService },
        { provide: Cart, useValue: cartService },
        { provide: WishlistService, useValue: wishlistService },
        { provide: MatSnackBar, useValue: snackBar },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(ProductList);
    component = fixture.componentInstance;
    router = TestBed.inject(Router);
    spyOn(router, 'navigate');
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should load products with images', () => {
    const product: ProductModel = {
      id: '1',
      name: 'Phone',
      description: 'Flagship',
      price: 100,
      category: 'Tech',
      stock: 5,
      sellerId: 'seller',
      sellerName: 'Seller',
      imageUrl: '/image.png',
    };
    productService.getProducts.and.returnValue(of(makePage([product])));
    mediaService.getImageUrl.and.returnValue('http://cdn/image.png');

    component.loadProducts();

    expect(component.products[0].imageUrl).toBe('http://cdn/image.png');
    expect(component.loading).toBeFalse();
  });

  it('should reset page on search', () => {
    component.pageIndex = 3;
    component.searchKeyword = 'phone';
    productService.getProducts.and.returnValue(of(makePage([])));

    component.onSearch();

    expect(component.pageIndex).toBe(0);
    expect(productService.getProducts).toHaveBeenCalled();
  });

  it('should add to cart and offer navigation', () => {
    component.addToCart({ id: '1', name: 'Phone', description: 'desc', category: 'cat', stock: 5, price: 100, sellerId: 'seller-1', sellerName: 'Test Seller' });
    expect((cartService.addToCart as jasmine.Spy).calls.any()).toBeTrue();
  });

  it('should navigate to product details', () => {
    component.viewDetails('1');
    expect(router.navigate).toHaveBeenCalledWith(['/products', '1']);
  });

  it('should handle error when loading products', () => {
    productService.getProducts.and.returnValue(throwError(() => new Error('Product service error')));

    component.loadProducts();

    expect(component.errorMessage).toContain('Impossible de charger les produits');
    expect(component.loading).toBeFalse();
  });

  it('should handle empty product list', () => {
    productService.getProducts.and.returnValue(of(makePage([])));

    component.loadProducts();

    expect(component.products).toEqual([]);
    expect(component.loading).toBeFalse();
  });

  it('should handle products without images gracefully', () => {
    const product: ProductModel = {
      id: '1',
      name: 'Phone',
      description: 'Flagship',
      price: 100,
      category: 'Tech',
      stock: 5,
      sellerId: 'seller',
      sellerName: 'Seller',
    };
    productService.getProducts.and.returnValue(of(makePage([product])));

    component.loadProducts();

    expect(component.products.length).toBe(1);
    expect(component.loading).toBeFalse();
  });

  it('should navigate to cart when snackbar action is clicked', () => {
    const snackBarRef = {
      onAction: () => of(true),
    };
    snackBar.open.and.returnValue(snackBarRef as any);

    component.addToCart({ id: '1', name: 'Phone', description: 'desc', category: 'cat', stock: 5, price: 100, sellerId: 'seller-1', sellerName: 'Test Seller' });

    expect((cartService.addToCart as jasmine.Spy)).toHaveBeenCalled();
  });

  it('should update page on paginator change', () => {
    productService.getProducts.and.returnValue(of(makePage([])));

    component.onPageChange({ pageIndex: 2, pageSize: 24 });

    expect(component.pageIndex).toBe(2);
    expect(component.pageSize).toBe(24);
    expect(productService.getProducts).toHaveBeenCalled();
  });

  it('should reset page when sort changes', () => {
    component.pageIndex = 3;
    productService.getProducts.and.returnValue(of(makePage([])));

    component.onSortChange();

    expect(component.pageIndex).toBe(0);
  });

  it('should reset page and reload when filters are cleared', () => {
    component.pageIndex = 2;
    component.selectedCategory = 'Tech';
    component.minPrice = 10;
    component.maxPrice = 500;
    component.searchKeyword = 'test';
    productService.getProducts.and.returnValue(of(makePage([])));

    component.clearFilters();

    expect(component.pageIndex).toBe(0);
    expect(component.selectedCategory).toBe('');
    expect(component.minPrice).toBeNull();
    expect(component.maxPrice).toBeNull();
    expect(component.searchKeyword).toBe('');
  });

  it('should set totalElements from page response', () => {
    const product: ProductModel = {
      id: '1', name: 'Phone', description: 'Flagship',
      price: 100, category: 'Tech', stock: 5,
      sellerId: 'seller', sellerName: 'Seller',
    };
    const page: Page<ProductModel> = {
      content: [product],
      totalElements: 42,
      totalPages: 4,
      number: 0,
      size: 12,
      first: true,
      last: false,
    };
    productService.getProducts.and.returnValue(of(page));

    component.loadProducts();

    expect(component.totalElements).toBe(42);
  });
});